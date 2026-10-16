import Foundation
import SwiftData
import PokeBattleKit

/// First-launch download + import for the pokedex and item lists.
///
/// Everything here runs off the main thread: network fetches and JSON
/// decoding fan out on the cooperative pool, and rows are built and saved
/// by `PokedexStore` on its background context. The UI then reads the
/// persisted rows through its own main-actor `ModelContext` / `@Query`.
///
/// Split by role: the Pokédex and Items tabs import (`PokedexImporting`),
/// search and the fighter picker read snapshots (`PokedexSnapshotReading`).
protocol PokedexImporting: Sendable {
    /// Download every pokemon (details, species, evolution chains) and
    /// persist them, unless they're already stored. `onProgress` reports
    /// 0...1 in whole-percent steps.
    func loadPokemonIfNeeded(onProgress: @escaping @Sendable (Double) async -> Void) async throws
    /// Download and persist every item category, unless already stored.
    func loadItemsIfNeeded() async throws
}

protocol PokedexSnapshotReading: Sendable {
    /// Full-text search haystacks for every stored pokemon, built off the
    /// main actor.
    func searchIndex() async -> [PokemonSearchEntry]
    /// Matchmaking snapshots for every stored pokemon, built off the main
    /// actor.
    func battleCandidates() async -> [Candidate]
}

typealias PokedexRepositoryProtocol = PokedexImporting & PokedexSnapshotReading

/// Production `PokedexRepositoryProtocol`. Writes through the injected
/// `PokedexStoreProvider`'s shared store (the pokedex and items tabs can
/// load at the same time). The actor itself does little
/// work: fetching and decoding happen in `PokeAPIClient`'s `@concurrent`
/// methods and child tasks, and persistence happens on the store.
///
/// First-launch pokemon pipeline:
/// 1. List + every `/pokemon/{id}` detail, in parallel.
/// 2. Every `/pokemon-species/{id}`, in parallel (failures are skipped).
/// 3. Every evolution chain referenced by a species, via `EvolutionService`.
/// 4. One `PokedexStore.importPokemon` that builds and saves all rows.
actor PokedexRepository {
    fileprivate static let pokemonLimit = 1150
    private static let itemLimit = 2048
    /// Bump to force a one-time item re-import after an import format change.
    /// v2: effect texts filtered to English.
    private static let itemDataVersion = 2
    private static let itemDataVersionKey = "items.dataVersion"

    private let stores: PokedexStoreProvider
    private let client: any PokeAPIFetching
    private let evolutionService: any EvolutionPrefetching
    private let defaults: UserDefaults

    init(
        stores: PokedexStoreProvider,
        evolutionService: any EvolutionPrefetching,
        client: any PokeAPIFetching = PokeAPIClient(),
        defaults: UserDefaults = .standard
    ) {
        self.stores = stores
        self.client = client
        self.evolutionService = evolutionService
        self.defaults = defaults
    }
}

// MARK: - PokedexRepositoryProtocol

extension PokedexRepository: PokedexRepositoryProtocol {
    func loadPokemonIfNeeded(onProgress: @escaping @Sendable (Double) async -> Void) async throws {
        let store = await resolvedStore()
        guard await store.pokemonCount() == 0 else { return }

        let progress = ProgressCounter(onProgress: onProgress)
        let tick: @Sendable () async -> Void = { await progress.tick() }
        // Local copy so the child tasks below capture a Sendable value
        // instead of actor-isolated `self`.
        let client = client

        let details = try await client.fetchAll(
            PokemonDTO.self,
            list: .pokemonList(limit: Self.pokemonLimit),
            detail: PokeAPIRequest.pokemonDetails,
            onTick: tick
        )
        // Units: one per detail, one per species, the (still estimated)
        // chains, and the final import.
        await progress.setTotal(details.count * 2 + ProgressCounter.estimatedChainCount + 1)

        // Species are optional enrichment: a failed request yields `nil` and
        // the pokemon is stored without habitat, flavor text, etc.
        let species = await withTaskGroup(of: (Int, PokemonSpecies)?.self) { group in
            for dto in details {
                let id = dto.id
                group.addTask {
                    guard let species: PokemonSpecies = try? await client.fetch(.pokemonSpecies("\(id)"))
                    else { return nil }
                    return (id, species)
                }
            }
            var byId: [Int: PokemonSpecies] = [:]
            for await result in group {
                if let (id, species) = result { byId[id] = species }
                await tick()
            }
            return byId
        }

        // Many species share a chain (e.g. Bulbasaur → Venusaur), hence the
        // `Set`. Now the real chain count is known, so replace the estimate.
        let chainIds = Set(species.values.compactMap(\.evolutionChain?.id))
        await progress.setRemaining(chainIds.count + 1)
        await evolutionService.prefetchChains(ids: chainIds, onTick: tick)

        // Import last: `pokemonCount() == 0` is the "needs download" check,
        // so an interrupted first launch starts over next time (reusing any
        // chains that were already saved).
        try await store.importPokemon(details, species: species)
        await progress.finish()
    }

    /// Runs when no items are stored, or once after `itemDataVersion` is
    /// bumped (the stored version lives in `UserDefaults` under
    /// `items.dataVersion`). The version is only recorded after a
    /// successful import, so a failed attempt is retried on the next launch.
    func loadItemsIfNeeded() async throws {
        let store = await resolvedStore()
        let isOutdated = defaults.integer(forKey: Self.itemDataVersionKey) < Self.itemDataVersion
        let hasItems = await store.itemCategoryCount() > 0
        guard isOutdated || !hasItems else { return }

        // Download first: if it fails (e.g. offline), the existing rows stay.
        let details = try await client.fetchAll(
            ItemDetailDTO.self,
            list: .itemList(limit: Self.itemLimit),
            detail: PokeAPIRequest.itemDetails
        )
        if hasItems { try await store.deleteAllItems() }
        try await store.importItems(details)
        defaults.set(Self.itemDataVersion, forKey: Self.itemDataVersionKey)
    }

    func searchIndex() async -> [PokemonSearchEntry] {
        await resolvedStore().searchIndex()
    }

    func battleCandidates() async -> [Candidate] {
        await resolvedStore().battleCandidates()
    }
}

// MARK: - Private
private extension PokedexRepository {
    func resolvedStore() async -> PokedexStore {
        await stores.store()
    }
}

/// Counts download units and forwards progress only when the whole
/// percentage increases, so the UI sees ~100 monotonic updates instead of
/// thousands. An actor because ticks arrive from many concurrent download
/// tasks.
private actor ProgressCounter {
    /// Typical number of evolution chains, used until the real count is
    /// known after the species step.
    static let estimatedChainCount = 540

    private let onProgress: @Sendable (Double) async -> Void
    /// Estimate until the detail list size is known: details + species +
    /// chains + the final import step.
    private var total = PokedexRepository.pokemonLimit * 2 + estimatedChainCount + 1
    private var done = 0
    private var lastPercent = -1

    init(onProgress: @escaping @Sendable (Double) async -> Void) {
        self.onProgress = onProgress
    }

    func setTotal(_ value: Int) { total = max(value, done) }
    /// Replace the estimate for the remaining work once it's known.
    func setRemaining(_ value: Int) { total = done + value }

    func tick() async {
        done += 1
        await report()
    }

    func finish() async {
        done = total
        await report()
    }

    private func report() async {
        let fraction = min(1, Double(done) / Double(max(total, 1)))
        let percent = Int(fraction * 100)
        // Never step backwards when an estimate is corrected upwards.
        guard percent > lastPercent else { return }
        lastPercent = percent
        await onProgress(fraction)
    }
}
