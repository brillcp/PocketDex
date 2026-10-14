import Foundation
import SwiftData

/// Evolution chains from `/evolution-chain/{id}` with two-tier caching:
/// an in-memory map for hot reads and SwiftData for cross-launch reuse.
protocol EvolutionServiceProtocol: Sendable {
    /// Fetch the chain by id. Cache-first.
    func requestChain(id: String) async throws -> EvolutionChain
}

actor EvolutionService {
    private let client: PokeAPIClient
    private let modelContainer: ModelContainer
    private var store: PokedexStore?
    private var cache: [String: EvolutionChain] = [:]

    init(modelContainer: ModelContainer) {
        self.init(modelContainer: modelContainer, client: PokeAPIClient())
    }

    init(modelContainer: ModelContainer, client: PokeAPIClient) {
        self.modelContainer = modelContainer
        self.client = client
    }
}

// MARK: - EvolutionServiceProtocol

extension EvolutionService: EvolutionServiceProtocol {
    func requestChain(id: String) async throws -> EvolutionChain {
        if let hit = cache[id] { return hit }

        let store = await resolvedStore()
        if let data = await store.chainPayload(id: id),
           let stored = try? JSONDecoder().decode(EvolutionChain.self, from: data) {
            cache[id] = stored
            return stored
        }

        let chain: EvolutionChain = try await client.fetch(.evolutionChain(id))
        cache[id] = chain
        if let data = try? JSONEncoder().encode(chain) {
            try? await store.storeChains([EvolutionChainPayload(chainId: id, payload: data)])
        }
        return chain
    }
}

// MARK: - Bootstrap

extension EvolutionService {
    /// Download every chain in `ids` that isn't persisted yet and store it.
    /// `onTick` fires once per id (cached ids tick immediately).
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
                          (try? JSONDecoder().decode(EvolutionChain.self, from: data)) != nil
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
        if let store { return store }
        let created = await PokedexStore.make(modelContainer: modelContainer)
        store = created
        return created
    }
}
