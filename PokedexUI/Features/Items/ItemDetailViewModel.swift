import Foundation

/// Protocol for a view model that provides item details and a title for display.
@MainActor
protocol ItemDetailViewModelProtocol {
    /// The collection of item details to be displayed.
    var items: [ItemDetail] { get }
    /// The title representing this group of items.
    var title: String { get }
}

/// View model that provides details and metadata for a single item.
@MainActor
@Observable
final class ItemDetailViewModel {
    let item: ItemData
    /// Sorted once on init instead of on every body evaluation.
    let items: [ItemDetail]

    init(item: ItemData) {
        self.item = item
        self.items = item.items.sorted(by: { $0.name < $1.name })
    }
}

// MARK: - ItemDetailViewModelProtocol

extension ItemDetailViewModel: ItemDetailViewModelProtocol {
    var title: String {
        item.title.pretty
    }
}
