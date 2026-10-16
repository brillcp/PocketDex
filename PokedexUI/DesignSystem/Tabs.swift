import Foundation

enum Tabs: Int {
    case pokedex, items, battle, search
}

extension Tabs {
    var title: String {
        switch self {
            case .pokedex: "PocketDex+"
            case .items: "Items"
            case .battle: "Gym"
            case .search: "Search"
        }
    }

    var icon: String {
        switch self {
            case .pokedex: GridLayout.three.icon
            case .items: "xmark.triangle.circle.square.fill"
            case .battle: "bolt.shield.fill"
            case .search: "magnifyingglass"
        }
    }
}
