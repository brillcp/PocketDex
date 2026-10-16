import Foundation

enum Tabs: Int {
    case pokedex, items, battle, search
}

extension Tabs {
    var title: String {
        switch self {
            case .pokedex: "PocketDex+"
            case .items: Localized("tab.items")
            case .battle: Localized("tab.battle")
            case .search: Localized("tab.search")
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
