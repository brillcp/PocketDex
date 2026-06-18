import SwiftUI

/// Async sprite loader backed by the shared `SpriteLoader` cache.
///
/// Loading is tied to `.task(id: url)`, so it is cancelled when a lazy grid
/// cell scrolls away and restarted if the URL changes. `onLoaded` runs
/// with the decoded image before it's shown, so callers (e.g. pokedex
/// cells) can derive a tint color from the same download.
struct SpriteImage: View {
    enum Style { case circle, plain }

    @Environment(\.container) private var container
    @Environment(\.featureFlags) private var featureFlags
    @State private var image: Image?
    @State private var tintColor: Color = .white

    let url: String?
    var style: Style = .circle
    var silhouetteTint: Color? = .white
    var onLoaded: ((UIImage) async -> Void)?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .renderingMode(featureFlags.silhouetteEnabled ? .template : .original)
                    .foregroundStyle(tintColor.opacity(featureFlags.silhouetteEnabled ? Opacity.silhouette : 1))
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: url) {
            guard let url,
                  let uiImage = await container.spriteLoader.spriteImage(from: url)
            else { return }
            await onLoaded?(uiImage)
            let dominant = await container.imageColorAnalyzer.dominantColor(for: url.hashValue, image: uiImage)
            let isLight = dominant?.isLight ?? false
            withAnimation(DesignKit.Animation.Primitive.easeInOut20) {
                tintColor = silhouetteTint ?? (isLight ? .black : .white)
                image = Image(uiImage: uiImage)
            }
        }
    }
}

// MARK: - Private
private extension SpriteImage {
    @ViewBuilder var placeholder: some View {
        switch style {
        case .circle:
            Color.white.opacity(0.05).clipShape(Circle())
        case .plain:
            Color.white.opacity(0.05)
        }
    }
}
