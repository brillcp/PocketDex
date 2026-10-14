import SwiftUI

/// Reusable grid column layouts used across Pokemon and move grids.
///
/// The raw value is the column count. Columns are equal `.flexible` items,
/// so cells stretch to fill any width (iPhone, the narrow grid column on
/// iPad/unfolded iPhone Duo, resized windows) without per-device sizes.
enum GridLayout: Int {
    case two = 2, three, four
}

extension GridLayout {
    var spacing: CGFloat { 2.0 }

    var layout: [GridItem] {
        Array(repeating: GridItem(.flexible(maximum: .infinity), spacing: spacing), count: rawValue)
    }

    var icon: String {
        switch self {
            case .two: "square.grid.2x2.fill"
            case .three: "square.grid.3x3.fill"
            case .four: "square.grid.4x3.fill"
        }
    }

    /// Icon for the layout `toggle()` switches to (toolbar button image).
    var otherIcon: String {
        switch self {
            case .two: "square.grid.3x3.fill"
            case .three: "square.grid.4x3.fill"
            case .four: "square.grid.3x3.fill"
        }
    }
}

extension GridLayout {
    /// Toggles between three and four columns (pokedex toolbar).
    mutating func toggle() {
        switch self {
            case .three: self = .four
            case .four: self = .three
            case .two: self = .three
        }
    }
}
