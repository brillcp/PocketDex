import SwiftUI
import SwiftData

/// Root tab host for pokedex, items, favourites, and search. Each tab
/// builds its own view model inline; the pokedex view model is hoisted here
/// so its grid + sort state survives tab switches, and the search view
/// model so the tab view can own the search field.
///
/// Search follows the iOS 26 pattern: a `.search` role tab (its own button,
/// pinned to the trailing edge) with `.searchable` on the `TabView` and
/// `.searchTabSelection` activation, so selecting it turns the tab bar into
/// the search field above the keyboard instead of a field in the navigation
/// bar.
///
/// The inline view models are safe to construct in `body`: each tab view
/// stores its model in `@State`, which keeps the first instance for the
/// view's lifetime and ignores the new ones built on later evaluations.
struct RootTabView<PokedexViewModel: PokedexViewModelProtocol>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.container) private var container

    @State var viewModel: PokedexViewModel
    @State var searchViewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            Tab(Tabs.pokedex.title, systemImage: viewModel.grid.icon, value: Tabs.pokedex, content: pokedexTab)
            Tab(Tabs.battle.title, systemImage: Tabs.battle.icon, value: Tabs.battle, content: battleTab)
            Tab(Tabs.items.title, systemImage: Tabs.items.icon, value: Tabs.items, content: itemsTab)
            // System title and symbol, so it gets the separate search
            // button treatment.
            Tab(value: Tabs.search, role: .search, content: searchTab)
        }
        .searchable(text: $searchViewModel.query)
        // Selecting the tab focuses the field above the keyboard; dismissing
        // search returns to the previous tab.
        .tabViewSearchActivation(.searchTabSelection)
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search, searchViewModel.recordSearch)
        // Leaving the field counts as a search, like pressing return.
        .onChange(of: isSearchFocused) { old, new in
            guard old, !new, !searchViewModel.query.isEmpty else { return }
            searchViewModel.recordSearch()
        }
        .task { await viewModel.requestPokemon() }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.openFavourites, content: BookmarksView.init)
    }
}

// MARK: - Private
private extension RootTabView {
    func pokedexTab() -> some View {
        PokedexContent(viewModel: viewModel)
    }

    func itemsTab() -> some View {
        ItemListView(viewModel: ItemListViewModel(modelContext: modelContext, container: container))
    }

    func searchTab() -> some View {
        SearchView(viewModel: searchViewModel)
    }

    func battleTab() -> some View {
        MultiplayerSetupView(viewModel: MultiplayerSetupViewModel(container: container))
    }
}

#Preview {
    @Previewable
    @Environment(\.modelContext) var modelContext
    RootTabView(
        viewModel: PokedexViewModel(modelContext: modelContext, container: .live),
        searchViewModel: SearchViewModel(repository: AppContainer.live.repository)
    )
}
