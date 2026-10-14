import Foundation
import SwiftData

/// Protocol for the observable view model behind the items tab.
@MainActor
protocol ItemListViewModelProtocol {
    /// Item categories, sorted by title.
    var items: [ItemData] { get }
    /// A flag indicating whether data is currently being fetched.
    var isLoading: Bool { get }

    /// Imports items on first launch if needed, then reads them from the store.
    /// No-op once items are loaded.
    func loadItems() async
}

/// Concrete implementation of `ItemListViewModelProtocol`. The repository
/// writes to the store in the background; this class only reads the result
/// through the main `ModelContext`.
@MainActor
@Observable
final class ItemListViewModel {
    private let repository: PokedexRepositoryProtocol
    private let modelContext: ModelContext

    var items: [ItemData] = []
    var isLoading: Bool = false

    init(modelContext: ModelContext, container: AppContainer) {
        self.repository = container.repository
        self.modelContext = modelContext
    }
}

// MARK: - ItemListViewModelProtocol

extension ItemListViewModel: ItemListViewModelProtocol {
    func loadItems() async {
        guard !isLoading, items.isEmpty else { return }

        items = await withLoadingState {
            // Downloads and imports off the main actor when nothing is
            // stored yet; the rows are then read through the main context.
            do {
                try await repository.loadItemsIfNeeded()
            } catch {
                #if DEBUG
                print("ItemListViewModel: fetch failed: \(error)")
                #endif
            }
            return (try? modelContext.fetch(FetchDescriptor<ItemData>(sortBy: [SortDescriptor(\.title)]))) ?? []
        }
    }
}

// MARK: - Private
private extension ItemListViewModel {
    func withLoadingState<T>(_ operation: () async throws -> T) async rethrows -> T {
        isLoading = true
        defer { isLoading = false }
        return try await operation()
    }
}
