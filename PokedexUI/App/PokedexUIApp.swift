import SwiftUI
import SwiftData
import PokeBattleKit

/// App entry point. Installs the shared `ModelContainer` from
/// `AppContainer.live` into the scene, so every view's `@Query` and
/// `\.modelContext` read the same store that `PokedexStore` writes to in the
/// background.
@main
struct PokedexUIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppContainer.live.modelContainer)
    }
}

/// Root view that wires up the composition root to the main content.
/// Lives below `.modelContainer(...)` so it can hand the main-actor
/// `ModelContext` (for UI-side reads) and the `AppContainer`
/// services to the root view model.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.container) private var container

    var body: some View {
        RootTabView(
            viewModel: PokedexViewModel(
                modelContext: modelContext,
                container: container
            )
        )
    }
}

// MARK: - AppDelegate

/// UIKit lifecycle hook, bridged in via `@UIApplicationDelegateAdaptor`.
/// Only used to kick off `PokeBattleKit.initialize()` at launch. The call
/// runs in an unstructured `Task` so `didFinishLaunching` returns
/// immediately instead of waiting on it; errors are deliberately ignored.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { try? await PokeBattleKit.initialize() }
        return true
    }
}
