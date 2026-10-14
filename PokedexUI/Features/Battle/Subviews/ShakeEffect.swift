import SwiftUI

/// Horizontal sine-wave shake effect driven by an incrementing tick.
///
/// `@Animatable` synthesizes `animatableData` for `progress`, so animating
/// the tick from n to n+1 sweeps the sine through `shakes` half-waves and
/// lands back at zero offset. The `@AnimatableIgnored` constants stay fixed.
@Animatable
struct ShakeEffect: GeometryEffect {
    @AnimatableIgnored var amount: CGFloat = 8
    @AnimatableIgnored var shakes: CGFloat = 3
    var progress: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(progress * .pi * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
