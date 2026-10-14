import SwiftUI
import SwiftData
import PokeBattleKit

/// App entry point.
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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { try? await PokeBattleKit.initialize() }
        return true
    }
}
