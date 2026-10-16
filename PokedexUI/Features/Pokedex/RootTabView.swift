import SwiftUI
import SwiftData

/// Root tab host for pokedex, battle, items, and search. The pokedex view
/// model is hoisted here so its grid + sort state survives tab switches,
/// and the multiplayer lobby's so it (with its handshake) is built once
/// rather than on every tab switch; the other tabs build theirs inline.
///
/// Search follows the iOS 26 pattern: a `.search` role tab with the system
/// title and symbol and `.searchTabSelection` activation, so it's a
/// separate button at the trailing edge and selecting it opens the field
/// above the keyboard. The field is owned by `SearchView` (on its
/// `NavigationStack`) rather than the `TabView`, so it never shows in the
/// other tabs' navigation bars.
///
/// The inline view models are safe to construct in `body`: each tab view
/// stores its model in `@State`, which keeps the first instance for the
/// view's lifetime and ignores the new ones built on later evaluations.
struct RootTabView<PokedexViewModel: PokedexViewModelProtocol>: View {
    @Environment(\.viewModels) private var viewModels

    @State var viewModel: PokedexViewModel
    @State var multiplayerSetup: MultiplayerSetupViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            Tab(Tabs.pokedex.title, systemImage: viewModel.grid.icon, value: Tabs.pokedex, content: pokedexTab)
            Tab(Tabs.battle.title, systemImage: Tabs.battle.icon, value: Tabs.battle, content: battleTab)
            Tab(Tabs.items.title, systemImage: Tabs.items.icon, value: Tabs.items, content: itemsTab)
            Tab(value: Tabs.search, role: .search, content: searchTab)
        }
        .tabViewSearchActivation(.searchTabSelection)
        .task { await viewModel.requestPokemon() }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Private
private extension RootTabView {
    func pokedexTab() -> some View {
        PokedexContent(viewModel: viewModel)
    }

    func itemsTab() -> some View {
        ItemListView(viewModel: viewModels.items())
    }

    func searchTab() -> some View {
        SearchView(viewModel: viewModels.search())
    }

    func battleTab() -> some View {
        MultiplayerSetupView(viewModel: multiplayerSetup)
    }
}
