import SwiftUI

/// Two-tone horizontal bar showing male/female distribution.
struct GenderRow: View {
    let rate: Int
    let textColor: Color

    /// Whole-number percent, truncated to match the bar's eighths.
    private static let percentFormat: FloatingPointFormatStyle<Double>.Percent = .pixelPercent(rounding: .towardZero)

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("Gender")
                .frame(width: 82, alignment: .leading)
            if rate > 0 {
                let female = Double(rate) / 8.0
                let male = 1.0 - female
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
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
