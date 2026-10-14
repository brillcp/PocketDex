import Foundation
import SwiftData
import PokeBattleKit

/// Background SwiftData writer. Builds `@Model` rows from Sendable DTOs on
/// its own context and saves them; only DTOs, counts, and raw payloads
/// cross its boundary, never model instances.
///
/// Create it from a nonisolated context (see `PokedexStore.make`): a model
/// actor initialised on the main thread executes on the main thread.
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

    /// Battle-matchmaking snapshots for every stored pokemon.
    func opponentCandidates() -> [Candidate] {
        allPokemon().map { Candidate(pokemon: $0) }
    }

    private func allPokemon() -> [Pokemon] {
        (try? modelContext.fetch(FetchDescriptor<Pokemon>(sortBy: [SortDescriptor(\.id)]))) ?? []
    }

    // MARK: Items

    func itemCategoryCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<ItemData>())) ?? 0
    }

    /// Delete every item row (categories, details, sprites, effects) so the
    /// next load re-imports them.
    func deleteAllItems() throws {
        try modelContext.delete(model: ItemData.self)
        try modelContext.delete(model: ItemDetail.self)
        try modelContext.delete(model: ItemSprite.self)
        try modelContext.delete(model: Effect.self)
        try modelContext.save()
    }

    /// Group items with sprites by category and persist one `ItemData` per
    /// category.
    func importItems(_ details: [ItemDetailDTO]) throws {
        let withSprites = details.filter { $0.sprites?.default != nil }
        let grouped = Dictionary(grouping: withSprites, by: \.category.name)
        for (title, items) in grouped {
            modelContext.insert(ItemData(title: title, items: items.map(ItemDetail.init(dto:))))
        }
        try modelContext.save()
    }

    // MARK: Evolution chains

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
