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
    @State private var image: Image?

    let url: String?
    var style: Style = .circle
    var onLoaded: ((UIImage) async -> Void)?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
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
            withAnimation(.easeInOut(duration: 0.2)) {
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
