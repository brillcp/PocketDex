import SwiftUI

/// Centralised type-to-color map for the design system. Keys are PokeAPI's
/// lowercase type names; unknown types fall back to gray.
enum TypeColor {
    static func color(for name: String) -> Color {
        switch name {
        case "fire":                       return .orange
        case "water":                      return .blue
        case "grass":                      return .green
        case "electric":                   return .yellow
        case "psychic":                    return .pink
        case "ice":                        return .cyan
        case "fighting", "rock", "ground": return .brown
        case "poison", "ghost":            return .purple
        case "flying", "fairy":            return .mint
        case "bug":                        return .green.opacity(0.7)
        case "steel":                      return .gray
        case "dark":                       return .black
        case "dragon":                     return .indigo
        default:                           return .gray
        }
    }
}

/// Display helpers for a type-effectiveness multiplier. All resisted values
/// (x0.5 and x0.25) share the "×0.5" label to keep the chip short.
enum TypeEffectiveness {
    static func label(for mult: Double) -> String {
        switch mult {
        case 0: return "×0"
        case let m where m >= 2: return "×\(Int(m))"
        case let m where m == 1: return "×1"
        case let m where m < 1: return "×0.5"
        default: return "×\(mult.formatted(.number.precision(.fractionLength(1))))"
        }
    }

    static func chipStyle(for mult: Double) -> Chip.Style {
        switch mult {
        case 0: return .custom(background: .black.opacity(0.5))
        case let m where m >= 2: return .success
        case let m where m < 1: return .danger
        default: return .neutral
        }
    }
}
