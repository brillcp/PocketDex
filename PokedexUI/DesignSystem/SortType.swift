import SwiftUI

/// Sort options for the pokedex toolbar menu.
enum SortType: Hashable {
    case number, name
    case height, weight, catchRate
    case stat(Stats)

    static let allCases: [Self] = [
        .number, .name, .height, .weight, .catchRate,
        .stat(.hp), .stat(.attack), .stat(.defense), .stat(.speed)
    ]
}

/// Ascending or descending sort direction.
enum SortDirection: Hashable {
    case ascending, descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }

    var label: LocalizedStringKey {
        switch self {
        case .ascending: "sort.direction.ascending"
        case .descending: "sort.direction.descending"
        }
    }

    var systemImage: String {
        switch self {
        case .ascending: "arrow.up"
        case .descending: "arrow.down"
        }
    }
}

/// Base stat subset available as sort keys.
enum Stats: String, CaseIterable {
    case hp, attack, defense, speed

    var displayName: LocalizedStringKey {
        switch self {
        case .hp: "sort.stat.hp"
        case .attack: "sort.stat.attack"
        case .defense: "sort.stat.defense"
        case .speed: "sort.stat.speed"
        }
    }
}

extension SortType {
    var title: LocalizedStringKey {
        switch self {
        case .number: "sort.type.number"
        case .name: "sort.type.name"
        case .height: "sort.type.height"
        case .weight: "sort.type.weight"
        case .catchRate: "sort.type.catchRate"
        case .stat(let name): name.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .number: "number"
        case .name: "textformat"
        case .height: "arrow.up.and.down"
        case .weight: "scalemass.fill"
        case .catchRate: "circle.dotted.and.circle"
        case .stat(let stat):
            switch stat {
            case .hp: "heart.fill"
            case .attack: "bolt.fill"
            case .defense: "shield.fill"
            case .speed: "speedometer"
            }
        }
    }

    /// Default direction when first selecting this sort type.
    var defaultDirection: SortDirection {
        switch self {
        case .number, .name: .ascending
        default: .descending
        }
    }
}

extension SortType {
    func comparator(direction: SortDirection) -> (Pokemon, Pokemon) -> Bool {
        let base = baseComparator
        if direction == .ascending {
            return base
        }
        return { a, b in base(b, a) }
    }

    /// Ascending comparator for each type.
    private var baseComparator: (Pokemon, Pokemon) -> Bool {
        switch self {
        case .number:
            return { $0.id < $1.id }
        case .name:
            return { $0.name < $1.name }
        case .height:
            return { $0.height < $1.height }
        case .weight:
            return { $0.weight < $1.weight }
        case .catchRate:
            return { $0.captureRate < $1.captureRate }
        case .stat(let stat):
            let name = stat.rawValue
            return { a, b in
                let l = a.stats.first { $0.stat.name == name }?.baseStat ?? 0
                let r = b.stats.first { $0.stat.name == name }?.baseStat ?? 0
                return l < r
            }
        }
    }
}
