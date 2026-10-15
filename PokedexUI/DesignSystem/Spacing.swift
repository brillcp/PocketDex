import CoreGraphics

/// Namespace for design tokens. Caseless enums, so tokens are referenced as
/// `DesignKit.Spacing.Primitive.s16` and nothing can be instantiated.
enum DesignKit {}

extension DesignKit {
    enum Spacing {}
}

extension DesignKit.Spacing {
    /// Raw spacing scale in points: fine 2pt steps up to 8, then 12 and 16,
    /// then 8pt increments up to 56. Each name matches its value.
///
/// Primitives are the raw scale. Every padding and stack spacing in the app
/// uses them instead of literal numbers, so spacing stays on the scale.
    enum Primitive {
        static let s0: CGFloat = 0
        static let s2: CGFloat = 2
        static let s4: CGFloat = 4
        static let s6: CGFloat = 6
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let s40: CGFloat = 40
        static let s44: CGFloat = 44
        static let s48: CGFloat = 48
        static let s56: CGFloat = 56
    }
}
