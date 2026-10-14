import SwiftUI

/// Pixel-art activity indicator with sharp-cornered rectangular spokes.
/// Pass `text` to render a label beneath the spinner.
///
/// Steps in discrete ticks (one spoke per tick, via a periodic
/// `TimelineView`) instead of rotating smoothly, which matches the pixel-art
/// look and only redraws `lineCount` times per second.
struct PixelSpinner: View {
    let size: CGFloat
    let color: Color
    let lineCount: Int
    let lineWidth: CGFloat
    let lineLength: CGFloat
    var text: String?

    init(
        size: CGFloat = 22,
        color: Color = .secondary,
        lineCount: Int = 8,
        lineWidth: CGFloat = 2.2,
        lineLength: CGFloat = 6.4,
        text: String? = nil
    ) {
        self.size = size
        self.color = color
        self.lineCount = lineCount
        self.lineWidth = lineWidth
        self.lineLength = lineLength
        self.text = text
    }

    var body: some View {
        Group {
            if let text {
                VStack(spacing: DesignKit.Spacing.Primitive.s16) {
                    spinnerView
                    Text(text)
                        .font(.pixel14)
                        .foregroundStyle(.secondary)
                }
            } else {
                spinnerView
            }
        }
        .accessibilityLabel("Loading")
    }
}

// MARK: - Private
private extension PixelSpinner {
    var spinnerView: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / Double(lineCount))) { context in
            let step = currentStep(at: context.date)
            spokeRing
                .rotationEffect(.degrees(Double(step) * stepAngle))
                .frame(width: size, height: size)
        }
    }

    var spokeRing: some View {
        ZStack {
            ForEach(0..<lineCount, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: lineWidth, height: lineLength)
                    .offset(y: -(size / 2 - lineLength / 2))
                    .rotationEffect(.degrees(Double(index) * stepAngle))
                    .opacity(Double(index + 1) / Double(lineCount))
            }
        }
    }

    var stepAngle: Double { 360.0 / Double(lineCount) }

    func currentStep(at date: Date) -> Int {
        let seconds = date.timeIntervalSinceReferenceDate
        return Int(seconds * Double(lineCount)) % lineCount
    }
}

#Preview {
    VStack(spacing: DesignKit.Spacing.Primitive.s32) {
        PixelSpinner()
        PixelSpinner(text: "Loading items")
        PixelSpinner(size: 48, color: .yellow, lineWidth: 3, lineLength: 12)
        PixelSpinner(size: 64, color: .white, lineCount: 16, lineWidth: 2, lineLength: 14)
    }
    .padding(DesignKit.Spacing.Primitive.s16)
    .background(Color.black)
}
