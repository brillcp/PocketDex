import Foundation

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

    var label: LocalizedStringResource {
        switch self {
        case .ascending: "Ascending"
        case .descending: "Descending"
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

    var displayName: LocalizedStringResource {
        switch self {
        case .hp: "Hp"
        case .attack: "Attack"
        case .defense: "Defense"
        case .speed: "Speed"
        }
    }
}

extension SortType {
    var title: LocalizedStringResource {
        switch self {
        case .number: "Number"
        case .name: "Name"
        case .height: "Height"
        case .weight: "Weight"
        case .catchRate: "Catch rate"
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
