import Foundation

extension String {
    /// Replaces the (narrow) non-breaking spaces that format styles insert,
    /// e.g. between a value and its unit, with a regular space: the pixel
    /// font has no glyph for them and draws an underscore instead.
    var pixelFontSafe: String {
        replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    var pretty: String {
        self
            .replacingOccurrences(of: "-", with: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .firstUppercased
    }
}

extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    /// Whole-number percent rendered as "18%". Pinned to a POSIX locale
    /// because many locales put a non-breaking space before "%", which the
    /// pixel font draws as an underscore ("18_%").
    static func pixelPercent(rounding: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self {
        .percent
            .precision(.fractionLength(0))
            .rounded(rule: rounding)
            .locale(Locale(identifier: "en_US_POSIX"))
    }
}

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }

    var normalize: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
          .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
