import Foundation
import SwiftUI

// MARK: - Localization

/// Looks up `key` in Localizable.strings and substitutes any `args` into its
/// stored format placeholders. Falls back to `key` itself if missing.
///
/// SwiftUI views and the app's own components take `LocalizedStringKey`s,
/// so views pass keys straight in (`Text("key")`, `Chip("key")`), with
/// interpolated values for formatted strings (`Text("move.pp \(pp)")` looks
/// up `"move.pp %lld"`). Use this where a plain `String` is needed (view
/// models, the battle log).
nonisolated func Localized(_ key: String, _ args: CVarArg...) -> String {
    formattedLocalizedString(key, args)
}

/// Formats with the current locale so numbers use the user's digits and
/// entries in Localizable.stringsdict pick the right plural form.
nonisolated private func formattedLocalizedString(_ key: String, _ args: [CVarArg]) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    return String(format: format, locale: .current, arguments: args)
}

/// Looks up `key` and fills its `%@` (or positional `%1$@`) placeholders
/// with styled `parts`, so a whole sentence stays one translatable string
/// while names and highlights keep their own color or weight.
nonisolated func LocalizedAttributed(_ key: String, _ parts: AttributedString...) -> AttributedString {
    LocalizedAttributed(key, parts: parts)
}

/// ``LocalizedAttributed(_:_:)`` with the parts as an array.
nonisolated func LocalizedAttributed(_ key: String, parts: [AttributedString]) -> AttributedString {
    let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    var result = AttributedString()
    var rest = Substring(format)
    var nextIndex = 0
    while let range = rest.range(of: #"%(\d+\$)?@"#, options: .regularExpression) {
        result += AttributedString(String(rest[..<range.lowerBound]))
        let position = Int(rest[range].dropFirst().prefix { $0.isNumber }).map { $0 - 1 } ?? nextIndex
        if parts.indices.contains(position) { result += parts[position] }
        nextIndex += 1
        rest = rest[range.upperBound...]
    }
    result += AttributedString(String(rest))
    return result
}
