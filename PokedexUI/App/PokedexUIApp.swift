import SwiftUI
import SwiftData

/// App entry point. Injects the composition root and installs its
/// `ModelContainer` into the scene, so every view's `@Query` and
/// `\.modelContext` read the same store that `PokedexStore` writes to in the
/// background.
@main
struct PokedexUIApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.container, container)
        }
        .modelContainer(container.modelContainer)
    }
}

/// Root view that wires up the composition root to the main content, and
/// starts loading the battle catalogue at launch through the injected
/// container. A failed load is ignored here: the loadout screen loads again
/// before a battle (it's safe to call repeatedly) and shows the error if it
/// still fails.
private struct RootView: View {
    @Environment(\.container) private var container
    @Environment(\.viewModels) private var viewModels

    var body: some View {
        RootTabView(viewModel: viewModels.pokedex(), multiplayerSetup: viewModels.multiplayerSetup())
            .task { try? await container.battleCatalog.load() }
    }
}
