import Foundation

/// Top-level TabView selection for the root pokedex screen. `favourites`
/// isn't a tab; it's presented as a sheet but shares the title/icon table.
enum Tabs: Int {
    case pokedex, items, favourites, battle, search
}

extension Tabs {
    var title: String {
        switch self {
            case .pokedex: "PocketDex+"
            case .items: "Items"
            case .favourites: "Favourites"
            case .battle: "Gym"
            case .search: "Search"
        }
    }

    var icon: String {
        switch self {
            case .pokedex: GridLayout.three.icon
            case .items: "xmark.triangle.circle.square.fill"
            case .favourites: "heart.fill"
            case .battle: "bolt.shield.fill"
            case .search: "magnifyingglass"
        }
    }
}
