import SwiftUI

/// Horizontal sine-wave shake effect driven by an incrementing tick.
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
