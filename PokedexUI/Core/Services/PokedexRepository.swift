import Foundation
import SwiftData
import PokeBattleKit

/// First-launch download + import for the pokedex and item lists.
///
/// Everything here runs off the main thread: network fetches and JSON
/// decoding fan out on the cooperative pool, and rows are built and saved
/// by `PokedexStore` on its background context. The UI then reads the
/// persisted rows through its own main-actor `ModelContext` / `@Query`.
protocol PokedexRepositoryProtocol: Sendable {
    /// Download every pokemon (details, species, evolution chains) and
    /// persist them, unless they're already stored. `onProgress` reports
    /// 0...1 in whole-percent steps.
    func loadPokemonIfNeeded(onProgress: @escaping @Sendable (Double) async -> Void) async throws
    /// Download and persist every item category, unless already stored.
    func loadItemsIfNeeded() async throws
    /// Full-text search haystacks for every stored pokemon, built off the
    /// main actor.
    func searchIndex() async -> [PokemonSearchEntry]
    /// Matchmaking snapshots for every stored pokemon, built off the main
    /// actor.
    func opponentCandidates() async -> [Candidate]
}

actor PokedexRepository {
    private static let pokemonLimit = 1150
    private static let itemLimit = 2048
    /// Bump to force a one-time item re-import after an import format change.
    /// v2: effect texts filtered to English.
    private static let itemDataVersion = 2
    private static let itemDataVersionKey = "items.dataVersion"

    private let modelContainer: ModelContainer
    private let client: PokeAPIClient
    private let evolutionService: EvolutionService
    private var storeTask: Task<PokedexStore, Never>?

    init(modelContainer: ModelContainer, evolutionService: EvolutionService) {
        self.modelContainer = modelContainer
        self.client = PokeAPIClient()
        self.evolutionService = evolutionService
    }
}

// MARK: - PokedexRepositoryProtocol

extension PokedexRepository: PokedexRepositoryProtocol {
    func loadPokemonIfNeeded(onProgress: @escaping @Sendable (Double) async -> Void) async throws {
        let store = await resolvedStore()
        guard await store.pokemonCount() == 0 else { return }

        let progress = ProgressCounter(onProgress: onProgress)
        let tick: @Sendable () async -> Void = { await progress.tick() }
        let client = client

        let details = try await client.fetchAll(
            PokemonDTO.self,
            list: .pokemonList(limit: Self.pokemonLimit),
            detail: PokeAPIRequest.pokemonDetails,
            onTick: tick
        )
        await progress.setTotal(details.count * 2 + ProgressCounter.estimatedChainCount + 1)

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

        let chainIds = Set(species.values.compactMap(\.evolutionChain?.id))
        await progress.setRemaining(chainIds.count + 1)
        await evolutionService.prefetchChains(ids: chainIds, onTick: tick)

        try await store.importPokemon(details, species: species)
        await progress.finish()
    }

    func loadItemsIfNeeded() async throws {
        let store = await resolvedStore()
        let defaults = UserDefaults.standard
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

    func opponentCandidates() async -> [Candidate] {
        await resolvedStore().opponentCandidates()
    }
}

// MARK: - Private
private extension PokedexRepository {
    /// One shared store. Caching the creation task (not the result) means
    /// concurrent first callers await the same store instead of each
    /// creating their own across the suspension.
    func resolvedStore() async -> PokedexStore {
        if let storeTask { return await storeTask.value }
        let container = modelContainer
        let task = Task { await PokedexStore.make(modelContainer: container) }
        storeTask = task
        return await task.value
    }
}

/// Counts download units and forwards progress only when the whole
/// percentage increases, so the UI sees ~100 monotonic updates instead of
/// thousands.
private actor ProgressCounter {
    /// Typical number of evolution chains, used until the real count is
    /// known after the species step.
    static let estimatedChainCount = 540

    private let onProgress: @Sendable (Double) async -> Void
    /// Estimate until the detail list size is known: details + species +
    /// chains + the final import step.
    private var total = 1150 * 2 + estimatedChainCount + 1
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
