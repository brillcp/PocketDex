import SwiftUI

/// Animated `MeshGradient` backdrop tinted in shades of `color`.
///
/// Holds five brightness stops (±2) of `color` across a 3×3 mesh. The four
/// edge midpoints slide along their edges and the center wobbles in 2D so
/// the gradient drifts slowly; corners stay pinned so the gradient never
/// bleeds outside its bounds. Intended as a full-bleed background behind
/// detail screens.
///
/// `TimelineView(.animation)` redraws every frame, but only this view: the
/// noise and time offset are `@State` set once, so each instance looks
/// different and nothing upstream is invalidated.
struct MeshGradientBackground: View {
    let color: Color

    @State private var timeOffset      = Double.random(in: 0...1000)
    @State private var hueNoise        = (0..<9).map { _ in CGFloat.random(in: -0.04...0.04) }
    @State private var brightnessNoise = (0..<9).map { _ in CGFloat.random(in: -0.15...0.15) }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate + timeOffset
            MeshGradient(width: 3, height: 3, points: points(at: time), colors: shades(at: time))
        }
    }
}

// MARK: - Private
private extension MeshGradientBackground {
    func points(at t: TimeInterval) -> [SIMD2<Float>] {
        // Three-octave layered sines with irrational frequency ratios (√2, √3, φ, π…)
        // so the combined signal never repeats and each point/axis drifts independently.
        func w(_ slowF: Double, _ slowP: Double,
               _ midF:  Double, _ midP:  Double,
               _ fastF: Double, _ fastP: Double) -> Float {
            Float(0.22 * sin(t * slowF + slowP)
                + 0.08 * sin(t * midF  + midP)
                + 0.03 * cos(t * fastF + fastP))
        }

        let tmX = Float(0.5) + w(0.53, 0.00,  1.41, 2.30,  3.14, 0.70)
        let mlY = Float(0.5) + w(0.71, 1.10,  1.73, 3.10,  4.24, 1.90)
        let cnX = Float(0.5) + w(0.83, 2.00,  2.24, 0.80,  4.71, 2.50)
        let cnY = Float(0.5) + w(0.61, 0.50,  1.62, 1.70,  3.46, 0.30)
        let mrY = Float(0.5) + w(0.79, 3.00,  2.57, 0.40,  4.19, 3.10)
        let bmX = Float(0.5) + w(0.67, 1.70,  1.87, 2.60,  3.73, 1.30)

        return [
            SIMD2(0.00, 0.00),  // top-left  (pinned)
            SIMD2(tmX,  0.00),  // top-mid
            SIMD2(1.00, 0.00),  // top-right (pinned)
            SIMD2(0.00, mlY ),  // mid-left
            SIMD2(cnX,  cnY ),  // center
            SIMD2(1.00, mrY ),  // mid-right
            SIMD2(0.00, 1.00),  // bot-left  (pinned)
            SIMD2(bmX,  1.00),  // bot-mid
            SIMD2(1.00, 1.00),  // bot-right (pinned)
        ]
    }

    func shades(at t: TimeInterval) -> [Color] {
        func dh(_ f: Double, _ p: Double) -> CGFloat {
            CGFloat(0.02 * sin(t * f + p))
        }
        let baseHues: [CGFloat] = [
            -0.035, -0.020,  0.020,
            -0.025,  0.000,  0.015,
             0.020, -0.015,  0.015,
        ]
        let baseBrightness: [CGFloat] = [
            -0.22,  0.15,  0.22,
            -0.08,  0.00,  0.08,
             0.15, -0.15, -0.22,
        ]
        let drifts: [(Double, Double)] = [
            (0.11, 0.0), (0.17, 1.3), (0.13, 2.7),
            (0.19, 0.8), (0.23, 1.9), (0.15, 3.2),
            (0.21, 2.1), (0.09, 0.5), (0.14, 3.8),
        ]
        return (0..<9).map { i in
            color.shifted(
                hue:        baseHues[i]       + hueNoise[i]        + dh(drifts[i].0, drifts[i].1),
                brightness: baseBrightness[i] + brightnessNoise[i]
            )
        }
    }
}

#Preview {
    MeshGradientBackground(color: Color(hex: "d53b47")!)
        .ignoresSafeArea()
}
