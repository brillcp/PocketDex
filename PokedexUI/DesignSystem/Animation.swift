import SwiftUI

extension DesignKit {
    enum Animation {}
}

extension DesignKit.Animation {
    /// Raw animation scale. Each name is the curve plus its duration in
    /// hundredths of a second (`easeOut25` is `.easeOut(duration: 0.25)`).
    /// Springs append the damping fraction (`spring60d75` is response 0.6,
    /// damping 0.75). Unsuffixed names use SwiftUI's default duration.
    ///
    /// Every animation in the app uses these instead of literal curves, so
    /// motion stays consistent.
    enum Primitive {
        static let `default`: SwiftUI.Animation = .default

        // MARK: Ease

        static let easeOut: SwiftUI.Animation = .easeOut
        static let easeOut10: SwiftUI.Animation = .easeOut(duration: 0.10)
        static let easeOut20: SwiftUI.Animation = .easeOut(duration: 0.2)
        static let easeOut25: SwiftUI.Animation = .easeOut(duration: 0.25)
        static let easeOut40: SwiftUI.Animation = .easeOut(duration: 0.4)
        static let easeOut50: SwiftUI.Animation = .easeOut(duration: 0.5)
        static let easeOut120: SwiftUI.Animation = .easeOut(duration: 1.2)

        static let easeIn50: SwiftUI.Animation = .easeIn(duration: 0.5)

        static let easeInOut20: SwiftUI.Animation = .easeInOut(duration: 0.2)
        static let easeInOut25: SwiftUI.Animation = .easeInOut(duration: 0.25)

        // MARK: Snappy / Bouncy

        static let snappy: SwiftUI.Animation = .snappy
        static let snappy20: SwiftUI.Animation = .snappy(duration: 0.2)
        static let snappy25: SwiftUI.Animation = .snappy(duration: 0.25)

        static let bouncy25: SwiftUI.Animation = .bouncy(duration: 0.25)
        static let bouncy35: SwiftUI.Animation = .bouncy(duration: 0.35)

        // MARK: Spring

        static let spring18d40: SwiftUI.Animation = .spring(response: 0.18, dampingFraction: 0.4)
        static let spring35d50: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.5)
        static let spring60d75: SwiftUI.Animation = .spring(response: 0.6, dampingFraction: 0.75)
    }
}
