import SwiftUI

extension EnvironmentValues {
    /// The composition root, read with `@Environment(\.container)`.
    /// Defaults to the shared `AppContainer.live`; previews and tests can
    /// override it with `.environment(\.container, ...)`, and everything
    /// below follows. The default is a `static let` rather than a fresh
    /// instance because `@Entry` re-evaluates its default expression on each
    /// read.
    @Entry var container: AppContainer = .live

    /// Builds view models for views, read with `@Environment(\.viewModels)`.
    /// A small value over the environment's container, so building it per
    /// read is cheap.
    var viewModels: ViewModelFactory { ViewModelFactory(container: container) }

    /// Sprite downloads, for leaf views that need only this service.
    var spriteLoader: any SpriteLoading { container.spriteLoader }

    /// Dominant sprite colors, for leaf views that need only this service.
    var imageColorAnalyzer: any ImageColorAnalyzing { container.imageColorAnalyzer }
}
