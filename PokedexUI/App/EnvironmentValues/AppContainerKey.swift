import SwiftUI

extension EnvironmentValues {
    /// The composition root, read with `@Environment(\.container)`.
    /// Defaults to the shared `AppContainer.live`, so nothing needs to inject
    /// it at the root; previews and tests can override it with
    /// `.environment(\.container, ...)`. The default is a `static let`
    /// rather than a fresh instance because `@Entry` re-evaluates its default
    /// expression on each read.
    @Entry var container: AppContainer = .live
    /// Remote feature flags. `RootView` injects the instance it fetches;
    /// the default is the shared `FeatureFlags.defaults` (a `static let`, so
    /// every read returns the same object instead of a new one).
    @Entry var featureFlags: FeatureFlags = .defaults
}
