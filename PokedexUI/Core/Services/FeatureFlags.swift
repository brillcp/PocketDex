import Foundation

/// Remote feature flags, fetched once at launch from the PocketDex+ flag
/// endpoint and read by views through `@Environment(\.featureFlags)`.
///
/// - `silhouetteEnabled`: render sprites as tinted silhouettes and hide
///   Pokémon names ("Who's that Pokémon?" mode).
/// - `nameSortEnabled`: switch the pokedex grid to alphabetical order.
///
/// `@MainActor @Observable`: it's UI state, so views re-render when a fetch
/// flips a flag. The initializer is `nonisolated` so the environment's
/// default (`FeatureFlags.defaults`) can be created outside the main actor.
@MainActor
@Observable
final class FeatureFlags {
    /// Built-in values, used as the environment default (previews, and any
    /// view outside `RootView`) before a real instance is injected.
    nonisolated static let defaults = FeatureFlags()

    private(set) var silhouetteEnabled: Bool = true
    private(set) var nameSortEnabled: Bool = false

    nonisolated init() {}

    /// Fetch the flags; on any network or decoding failure the built-in
    /// values stay in place.
    func fetch() async {
        guard let url = URL(string: "https://gidlof.dev/wp-json/pokedex/v1/flags"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let payload = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        silhouetteEnabled = payload["silhouette"] == 1
        nameSortEnabled = payload["sortByName"] == 1
    }
}
