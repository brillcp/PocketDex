import SwiftUI
import SwiftData

/// Root tab host for pokedex, items, favourites, and search. Each tab
/// builds its own view model inline; only the pokedex view model is
/// hoisted here so its grid + sort state survives tab switches.
///
/// The inline view models are safe to construct in `body`: each tab view
/// stores its model in `@State`, which keeps the first instance for the
/// view's lifetime and ignores the new ones built on later evaluations.
struct RootTabView<PokedexViewModel: PokedexViewModelProtocol>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.container) private var container

    @State var viewModel: PokedexViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            Tab(Tabs.pokedex.title, systemImage: viewModel.grid.icon, value: Tabs.pokedex, content: pokedexTab)
            Tab(Tabs.battle.title, systemImage: Tabs.battle.icon, value: Tabs.battle, content: battleTab)
            Tab(Tabs.items.title, systemImage: Tabs.items.icon, value: Tabs.items, content: itemsTab)
            Tab(Tabs.search.title, systemImage: Tabs.search.icon, value: Tabs.search, role: .search, content: searchTab)
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
        SearchView(viewModel: SearchViewModel(repository: container.repository))
    }

    func battleTab() -> some View {
        MultiplayerSetupView(viewModel: MultiplayerSetupViewModel(container: container))
    }
}

#Preview {
    @Previewable
    @Environment(\.modelContext) var modelContext
    RootTabView(viewModel: PokedexViewModel(modelContext: modelContext, container: .live))
}
