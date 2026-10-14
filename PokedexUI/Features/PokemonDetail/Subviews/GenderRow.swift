import SwiftUI

/// Two-tone horizontal bar showing male/female distribution. `rate` is
/// PokeAPI's female chance in eighths (0...8, or -1 for genderless); the
/// detail view only shows the row when it's above 0.
struct GenderRow: View {
    let rate: Int
    let textColor: Color

    /// Whole-number percent, truncated to match the bar's eighths.
    private static let percentFormat: FloatingPointFormatStyle<Double>.Percent = .pixelPercent(rounding: .towardZero)

    var body: some View {
        HStack(alignment: .top, spacing: DesignKit.Spacing.Primitive.s16) {
            Text("Gender")
                .frame(width: 82, alignment: .leading)
            if rate > 0 {
                let female = Double(rate) / 8.0
                let male = 1.0 - female
                VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s4) {
                    GeometryReader { proxy in
                        HStack(spacing: DesignKit.Spacing.Primitive.s0) {
                            Rectangle()
                                .fill(.blue)
                                .frame(width: proxy.size.width * male)
                            Rectangle()
                                .fill(.pink)
                                .frame(width: proxy.size.width * female)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 10)
                    HStack {
                        Text(
                            "♂ \(male, format: Self.percentFormat)"
                        )
                        Spacer()
                        Text(
                            "♀ \(female, format: Self.percentFormat)"
                        )
                    }
                    .font(.pixel12)
                    .foregroundStyle(textColor.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
