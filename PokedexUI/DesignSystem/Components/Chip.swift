import SwiftUI

/// Small inline pill used for type chips, badges, and status tags.
///
/// One component with a `Style` (colors) and `Size` (font and padding)
/// instead of ad-hoc capsules, so every tag in the app stays consistent.
/// Use `Chip.type(_:)` for Pokémon types, which picks the type's color.
struct Chip: View {
    let text: String
    let style: Style
    let size: Size

    init(_ text: String, style: Style = .neutral, size: Size = .small) {
        self.text = text
        self.style = style
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .lineLimit(1)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .foregroundStyle(style.foreground)
            // Every style is softened the same way, so custom colors
            // (type colors, sprite tints) read like the built-in ones.
            .background(style.background.opacity(0.7))
            .clipShape(RoundedRectangle.chip)
    }
}

extension Chip {
    enum Style {
        case neutral
        case accent
        case primary
        case success
        case danger
        case custom(background: Color, foreground: Color = .white)

        var background: Color {
            switch self {
            case .neutral: return .white.opacity(0.15)
            case .accent:  return .white.opacity(0.1)
            case .primary: return Color.pokedexRed
            case .success: return .green.opacity(0.4)
            case .danger:  return .red.opacity(0.4)
            case .custom(let bg, _): return bg
            }
        }

        var foreground: Color {
            switch self {
            case .neutral, .accent, .success, .danger: return .white
            case .primary: return .white
            case .custom(_, let fg): return fg
            }
        }
    }

    enum Size {
        case small
        case medium

        var font: Font {
            switch self {
            case .small:  return .pixel9
            case .medium: return .pixel12
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:  return 6
            case .medium: return 8
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small:  return 2
            case .medium: return 4
            }
        }
    }
}

extension Chip {
    /// Convenience for Pokemon type chips with auto color.
    static func type(_ name: String, size: Size = .small) -> Chip {
        Chip(
            name.uppercased(),
            style: .custom(background: TypeColor.color(for: name)),
            size: size
        )
    }

    /// Convenience for Pokemon type chips with auto color, from a `Type` model.
    static func type(_ type: Type, size: Size = .small) -> Chip {
        Chip(
            type.name.uppercased(),
            style: .custom(background: TypeColor.color(for: type.name)),
            size: size
        )
    }
}
