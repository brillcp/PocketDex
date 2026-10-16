import SwiftUI

extension EnvironmentValues {
    /// The composition root, read with `@Environment(\.container)`.
    /// Defaults to the shared `AppContainer.live`, so nothing needs to inject
    /// it at the root; previews and tests can override it with
    /// `.environment(\.container, ...)`. The default is a `static let`
    /// rather than a fresh instance because `@Entry` re-evaluates its default
    /// expression on each read.
    @Entry var container: AppContainer = .live

    /// Builds view models for views, read with `@Environment(\.viewModels)`.
    /// A small value over the same live container, so building it per read
    /// is cheap.
    @Entry var viewModels: ViewModelFactory = ViewModelFactory(container: .live)

    /// Sprite downloads, for leaf views that need only this service.
    @Entry var spriteLoader: any SpriteLoading = AppContainer.live.spriteLoader

    /// Dominant sprite colors, for leaf views that need only this service.
    @Entry var imageColorAnalyzer: any ImageColorAnalyzing = AppContainer.live.imageColorAnalyzer
}
