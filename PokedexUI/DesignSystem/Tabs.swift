import SwiftUI

enum Tabs: Int {
    case pokedex, items, battle, search
}

extension Tabs {
    var title: LocalizedStringKey {
        switch self {
            case .pokedex: "PocketDex+"
            case .items: "tab.items"
            case .battle: "tab.battle"
            case .search: "tab.search"
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
