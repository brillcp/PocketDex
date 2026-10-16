import Foundation
import SwiftData
import PokeBattleKit

/// Background SwiftData writer. Builds `@Model` rows from Sendable DTOs on
/// its own context and saves them; only DTOs, counts, and raw payloads
/// cross its boundary, never model instances.
///
/// Create it from a nonisolated context (see `PokedexStore.make`): a model
/// actor initialised on the main thread executes on the main thread.
///
/// `PokedexStoreProvider` creates one on the shared `ModelContainer` for
/// `PokedexRepository` and `EvolutionService`; the UI never talks to it
/// directly and instead sees saved rows through the main context / `@Query`.
@ModelActor
actor PokedexStore {
    /// Create the store off the main thread so its context, and therefore
    /// all of its work, runs on a background executor.
    @concurrent
    static func make(modelContainer: ModelContainer) async -> PokedexStore {
        PokedexStore(modelContainer: modelContainer)
    }

    // MARK: Pokemon

    func pokemonCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<Pokemon>())) ?? 0
    }

    /// Insert one row per detail payload, merging in its species (if it
    /// downloaded), and save once so the UI sees the whole pokedex appear
    /// in a single change.
    func importPokemon(_ details: [PokemonDTO], species: [Int: PokemonSpecies]) throws {
        for dto in details {
            modelContext.insert(Pokemon(dto: dto, species: species[dto.id]))
        }
        try modelContext.save()
    }

    /// Search haystacks for every stored pokemon. Walks each row's
    /// relationships here, on the background context, so the UI only
    /// receives Sendable strings.
    func searchIndex() -> [PokemonSearchEntry] {
        allPokemon().map { PokemonSearchEntry(id: $0.id, haystack: Pokemon.searchHaystack(for: $0)) }
    }

    /// Battle-matchmaking snapshots for every stored pokemon. `Candidate`
    /// is a Sendable value copy, so it can leave this actor where the
    /// `Pokemon` row can't.
    func battleCandidates() -> [Candidate] {
        allPokemon().map { Candidate(pokemon: $0) }
    }

    private func allPokemon() -> [Pokemon] {
        (try? modelContext.fetch(FetchDescriptor<Pokemon>(sortBy: [SortDescriptor(\.id)]))) ?? []
    }

    // MARK: Items

    func itemCategoryCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<ItemData>())) ?? 0
    }

    /// Delete every item row (categories, details, sprites, effects, and
    /// each detail's category `APIItem`) ahead of a re-import. Children are
    /// deleted explicitly because the relationships use the default nullify
    /// rule, which would otherwise leave orphaned rows behind.
    func deleteAllItems() throws {
        for detail in try modelContext.fetch(FetchDescriptor<ItemDetail>()) {
            modelContext.delete(detail.category)
            if let sprites = detail.sprites { modelContext.delete(sprites) }
            detail.effect.forEach(modelContext.delete)
            modelContext.delete(detail)
        }
        try modelContext.fetch(FetchDescriptor<ItemData>()).forEach(modelContext.delete)
        try modelContext.save()
    }

    /// Group items with sprites by category and persist one `ItemData` per
    /// category. Items without a sprite are skipped because the item grid
    /// has nothing to show for them.
    func importItems(_ details: [ItemDetailDTO]) throws {
        let withSprites = details.filter { $0.sprites?.default != nil }
        let grouped = Dictionary(grouping: withSprites, by: \.category.name)
        for (title, items) in grouped {
            modelContext.insert(ItemData(title: title, items: items.map(ItemDetail.init(dto:))))
        }
        try modelContext.save()
    }

    // MARK: Evolution chains

    // Chains are stored as the raw (snake_case) JSON payload rather than as
    // a model graph: the tree is only ever read whole, so `EvolutionService`
    // decodes it on demand with `JSONDecoder.pokeAPI()`.

    func storedChainIds() -> Set<String> {
        let rows = (try? modelContext.fetch(FetchDescriptor<EvolutionChainEntity>())) ?? []
        return Set(rows.map(\.chainId))
    }

    func chainPayload(id: String) -> Data? {
        let descriptor = FetchDescriptor<EvolutionChainEntity>(predicate: #Predicate { $0.chainId == id })
        return try? modelContext.fetch(descriptor).first?.payload
    }

    func storeChains(_ payloads: [EvolutionChainPayload]) throws {
        guard !payloads.isEmpty else { return }
        for payload in payloads {
            modelContext.insert(EvolutionChainEntity(chainId: payload.chainId, payload: payload.payload))
        }
        try modelContext.save()
    }
}
