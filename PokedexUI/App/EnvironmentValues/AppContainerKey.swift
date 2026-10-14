import SwiftUI

extension EnvironmentValues {
    /// The composition root, read with `@Environment(\.container)`.
    /// Defaults to the shared `AppContainer.live`, so nothing needs to inject
    /// it at the root; previews and tests can override it with
    /// `.environment(\.container, ...)`. The default is a `static let`
    /// rather than a fresh instance because `@Entry` re-evaluates its default
    /// expression on each read.
    @Entry var container: AppContainer = .live
}
