import SwiftUI

/// Extracts and caches dominant sprite colors via downsampled pixel scanning.
/// Shared via `AppContainer.imageColorAnalyzer`.
protocol ImageColorAnalyzing: Sendable {
    /// Extract the dominant non-black/white color for a pokemon sprite.
    func dominantColor(for id: Int, image: UIImage) async -> Color?
}

/// An actor because it owns a mutable cache, but the actor only guards that
/// cache. The pixel scan itself is a `@concurrent` static function, so the
/// actor is free while it runs (it suspends at `await Self.analyze`) and many
/// grid cells analyse their sprites in parallel off the main thread instead
/// of serialising on the actor. Two cells racing on the same id may both
/// scan; the result is identical, so that's cheaper than tracking in-flight
/// work.
actor ImageColorAnalyzer {
    private var cache = [Int: Color]()

    init() {}
}

// MARK: - ImageColorAnalyzing

extension ImageColorAnalyzer: ImageColorAnalyzing {
    func dominantColor(for id: Int, image: UIImage) async -> Color? {
        if let cached = cache[id] { return cached }
        guard let color = await Self.analyze(image) else { return nil }
        cache[id] = color
        return color
    }
}

// MARK: - Private
private extension ImageColorAnalyzer {
    /// Downsample to 50×50, histogram the opaque pixels (bytes are read as
    /// BGRA), drop rare colors, and return the most frequent one. Near-black
    /// and near-white (sprite outlines and highlights) are skipped when any
    /// other color qualifies.
    @concurrent
    static func analyze(_ image: UIImage) async -> Color? {
        guard let cgImage = image.resize(to: CGSize(width: 50, height: 50))?.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        var colorCounts: [RGB: Int] = [:]

        for x in 0..<width {
            for y in 0..<height {
                let index = ((width * y) + x) * 4
                let alpha = bytes[index + 3]
                guard alpha >= 127 else { continue }

                let color = RGB(
                    r: bytes[index + 2],
                    g: bytes[index + 1],
                    b: bytes[index + 0]
                )
                colorCounts[color, default: 0] += 1
            }
        }

        let threshold = Int(CGFloat(height) * 0.01)
        let sortedColors = colorCounts
            .filter { $0.value > threshold }
            .sorted { $0.value > $1.value }

        guard var dominant = sortedColors.first?.key else { return nil }

        if dominant.isBlackOrWhite,
           let fallback = sortedColors.first(where: { !$0.key.isBlackOrWhite })?.key {
            dominant = fallback
        }

        return dominant.toColor()
    }

    struct RGB: Hashable {
        let r: UInt8
        let g: UInt8
        let b: UInt8

        var isBlackOrWhite: Bool {
            (r > 232 && g > 232 && b > 232) || (r < 23 && g < 23 && b < 23)
        }

        func toColor() -> Color {
            Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }
}

private extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
