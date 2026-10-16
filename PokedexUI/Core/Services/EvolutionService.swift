import Foundation
import SwiftData

/// Evolution chains from `/evolution-chain/{id}` with two-tier caching:
/// an in-memory map for hot reads and SwiftData for cross-launch reuse.
protocol EvolutionServiceProtocol: Sendable {
    /// Fetch the chain by id. Cache-first.
    func requestChain(id: String) async throws -> EvolutionChain
}

/// Bulk chain download, used by the first-launch import.
protocol EvolutionPrefetching: Sendable {
    /// Download and store every chain in `ids` not stored yet; `onTick`
    /// fires once per chain.
    func prefetchChains(ids: Set<String>, onTick: (@Sendable () async -> Void)?) async
}

/// Production `EvolutionServiceProtocol`, shared by detail screens and by
/// `PokedexRepository` (which prefetches every chain on first launch).
///
/// Lookup order: in-memory `cache` → stored payload in SwiftData → network.
/// The actor serialises access to `cache`. Network responses are decoded
/// off the actor (in `PokeAPIClient.fetch` or task-group children), and
/// only Sendable `EvolutionChain` values and `Data` payloads cross to and
/// from `PokedexStore`.
actor EvolutionService {
    private let client: any PokeAPIFetching
    private let stores: PokedexStoreProvider
    private var cache: [String: EvolutionChain] = [:]

    init(stores: PokedexStoreProvider, client: any PokeAPIFetching = PokeAPIClient()) {
        self.stores = stores
        self.client = client
    }
}

// MARK: - EvolutionServiceProtocol

extension EvolutionService: EvolutionServiceProtocol {
    func requestChain(id: String) async throws -> EvolutionChain {
        if let hit = cache[id] { return hit }

        let store = await resolvedStore()
        if let data = await store.chainPayload(id: id),
           let stored = try? JSONDecoder.pokeAPI().decode(EvolutionChain.self, from: data) {
            cache[id] = stored
            return stored
        }

        // Re-encode with the snake_case encoder so the stored payload has
        // the same shape as the raw API bytes `prefetchChains` saves.
        // Persisting is best-effort; the chain is returned either way.
        let chain: EvolutionChain = try await client.fetch(.evolutionChain(id))
        cache[id] = chain
        if let data = try? JSONEncoder.pokeAPI().encode(chain) {
            try? await store.storeChains([EvolutionChainPayload(chainId: id, payload: data)])
        }
        return chain
    }
}

// MARK: - EvolutionPrefetching

extension EvolutionService: EvolutionPrefetching {
    /// Download every chain in `ids` that isn't persisted yet and store it.
    /// `onTick` fires once per id (cached ids tick immediately).
    ///
    /// Stores the raw response bytes rather than re-encoding, but decodes
    /// each one first so a malformed payload is never persisted. Failed ids
    /// are skipped; `requestChain` fetches them on demand later. All
    /// payloads are saved in one batch at the end.
    func prefetchChains(ids: Set<String>, onTick: (@Sendable () async -> Void)?) async {
        let store = await resolvedStore()
        let persisted = await store.storedChainIds()
        let missing = ids.subtracting(persisted)

        for _ in 0..<(ids.count - missing.count) { await onTick?() }
        guard !missing.isEmpty else { return }

        let client = client
        let payloads = await withTaskGroup(of: EvolutionChainPayload?.self) { group in
            for id in missing {
                group.addTask {
                    guard let data = try? await client.fetchData(.evolutionChain(id)),
                          (try? JSONDecoder.pokeAPI().decode(EvolutionChain.self, from: data)) != nil
                    else { return nil }
                    return EvolutionChainPayload(chainId: id, payload: data)
                }
            }
            var collected: [EvolutionChainPayload] = []
            for await payload in group {
                if let payload { collected.append(payload) }
                await onTick?()
            }
            return collected
        }
        try? await store.storeChains(payloads)
    }
}

// MARK: - Private
private extension EvolutionService {
    func resolvedStore() async -> PokedexStore {
        await stores.store()
    }
}
