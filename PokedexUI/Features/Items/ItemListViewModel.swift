import Foundation
import SwiftData

/// Protocol for an observable view model that manages items and supports searching.
@MainActor
protocol ItemListViewModelProtocol {
    /// The current list of items being displayed.
    var items: [ItemData] { get }
    /// A flag indicating whether data is currently being fetched.
    var isLoading: Bool { get }

    /// Loads all items asynchronously from the data source.
    func loadItems() async
}

/// View model that manages the retrieval, searching, and storage of items.
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
