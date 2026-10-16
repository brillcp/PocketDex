import SwiftData

/// Hands out the one background `PokedexStore` on the shared
/// `ModelContainer`, created on first use. `AppContainer` builds one and
/// injects it into the services that write in the background
/// (`PokedexRepository`, `EvolutionService`), so none of them creates a
/// store itself and tests can point them at an in-memory container.
actor PokedexStoreProvider {
    private let modelContainer: ModelContainer
    private var storeTask: Task<PokedexStore, Never>?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Caches the creation task (not the result) so concurrent first callers
    /// share one store: a second caller arriving while `make` is suspended
    /// awaits the same task instead of creating another store.
    func store() async -> PokedexStore {
        if let storeTask { return await storeTask.value }
        let container = modelContainer
        let task = Task { await PokedexStore.make(modelContainer: container) }
        storeTask = task
        return await task.value
    }
}
