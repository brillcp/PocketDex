import SwiftUI

extension Color {
    static let darkGrey = Color(hex: "181818")!
    static let pokedexRed = Color(hex: "d53b47")!
    static let cardBackground = Color(hex: "202020")!

    init?(hex: String, alpha: Double = 1.0) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString

        guard let hexNumber = UInt64(hexString, radix: 16), hexString.count == 6 else { return nil }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b, opacity: alpha)
    }

    /// Perceived brightness (ITU-R BT.601 weights) above 0.6. Used to choose
    /// dark vs. white text over sprite-derived colors.
    var isLight: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let brightness = (red * 299 + green * 587 + blue * 114) / 1000
            return brightness > 0.6
        }
        return false
    }

    /// Returns the color with its HSB brightness shifted by `delta`, clamped to [0, 1].
    func shifted(brightness delta: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }
        return Color(hue: h, saturation: s, brightness: min(max(b + delta, 0), 1), opacity: a)
    }

    /// Returns the color with its HSB hue and brightness shifted, both wrapping/clamping to [0, 1].
    func shifted(hue dh: CGFloat, brightness db: CGFloat = 0) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }
        return Color(hue: (h + dh).truncatingRemainder(dividingBy: 1),
                     saturation: s,
                     brightness: min(max(b + db, 0), 1),
                     opacity: a)
    }
}

/// Standard opacity values used across the design system.
enum Opacity {
    static let disabled: Double = 0.4
}

/// Standard corner radii used across the design system.
enum CornerRadius {
    static let chip: CGFloat = 2.0
    static let card: CGFloat = 4.0
}

extension RoundedRectangle {
    static var chip: RoundedRectangle {
        RoundedRectangle(cornerRadius: CornerRadius.chip)
    }

    static var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: CornerRadius.card)
    }
}
