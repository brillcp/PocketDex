import SwiftUI

/// The app's pixel font, at fixed design sizes that scale with the user's
/// text size. Each size scales relative to the text style it stands in for,
/// so small labels grow more gently than titles.
extension Font {
    private static let pixelmix = "pixelmix Regular"

    static let pixel18 = Font.custom(pixelmix, size: 18.0, relativeTo: .title3)
    static let pixel16 = Font.custom(pixelmix, size: 16.0, relativeTo: .headline)
    static let pixel14 = Font.custom(pixelmix, size: 14.0, relativeTo: .body)
    static let pixel12 = Font.custom(pixelmix, size: 12.0, relativeTo: .footnote)
    static let pixel9 = Font.custom(pixelmix, size: 9.0, relativeTo: .caption2)
}
