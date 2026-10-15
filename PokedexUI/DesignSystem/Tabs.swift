import Foundation

enum Tabs: Int {
    case pokedex, items, myTeam, battle, search
}

extension Tabs {
    var title: String {
        switch self {
            case .pokedex: "PocketDex+"
            case .items: "Items"
            case .myTeam: "My team"
            case .battle: "Gym"
            case .search: "Search"
        }
    }

    var icon: String {
        switch self {
            case .pokedex: GridLayout.three.icon
            case .items: "xmark.triangle.circle.square.fill"
            case .myTeam: "person.2.fill"
            case .battle: "bolt.shield.fill"
            case .search: "magnifyingglass"
        }
    }
}
