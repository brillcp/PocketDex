import SwiftUI
import SwiftData

/// Pokedex tab content with grid and toolbar.
///
/// In compact width (iPhone, folded iPhone Duo) the grid pushes the detail
/// view onto a single stack. In regular width (unfolded iPhone Duo, iPad,
/// wide windows) the detail sits in a leading column and the grid in a
/// trailing column. The layout follows the size class rather than the
/// device, so it adapts live as the window resizes or the device folds.
struct PokedexContent<ViewModel: PokedexViewModelProtocol>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let viewModel: ViewModel

    /// Pushed detail in compact width.
    @State private var path: [Pokemon] = []
    /// Detail shown in the leading column in regular width.
    @State private var selection: Pokemon?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                sideBySide
            } else {
                NavigationStack(path: $path) {
                    PokedexGridColumn(viewModel: viewModel, selection: nil)
                }
                // Popping back to the grid closes the Pokémon, so it isn't
                // restored into the detail column after widening.
                .onChange(of: path) { _, newPath in
                    if newPath.isEmpty { selection = nil }
                }
            }
        }
        // Carry the open Pokémon across fold/unfold so it stays on screen.
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .regular {
                selection = path.first ?? selection
                path = []
            } else {
                path = selection.map { [$0] } ?? []
            }
        }
    }

    private var sideBySide: some View {
        HStack(spacing: 0) {
            PokedexDetailColumn(selection: selection)
                // New identity per selection: fresh detail state and a reset
                // stack (evolutions, type lists, battles pushed inside it).
                .id(selection?.id)

            Divider()

            NavigationStack {
                PokedexGridColumn(viewModel: viewModel, selection: $selection)
            }
            .containerRelativeFrame(.horizontal) { width, _ in width * 0.4 }
        }
    }
}

/// Grid, styling, and toolbar. A separate view so loading progress, sort,
/// and grid changes don't re-evaluate the detail column.
private struct PokedexGridColumn<ViewModel: PokedexViewModelProtocol>: View {
    let viewModel: ViewModel
    let selection: Binding<Pokemon?>?

    var body: some View {
        PokedexGridView(
            pokemon: viewModel.sortedPokemon,
            grid: viewModel.grid,
            isLoading: viewModel.isLoading,
            loadingProgress: viewModel.loadingProgress,
            selection: selection
        )
        .applyPokedexStyling(title: Tabs.pokedex.title)
        .toolbar { PokedexToolbar(viewModel: viewModel) }
        .animation(.snappy(duration: 0.25), value: viewModel.sortType)
        .animation(.snappy(duration: 0.25), value: viewModel.sortDirection)
    }
}

/// Leading column in regular width: the selected Pokémon's detail, or a
/// placeholder (untitled, so only the grid column shows the app title).
private struct PokedexDetailColumn: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext

    let selection: Pokemon?

    var body: some View {
        NavigationStack {
            if let selection {
                PokemonDetailView(
                    viewModel: PokemonDetailViewModel(
                        summary: selection,
                        container: container,
                        modelContext: modelContext
                    )
                )
            } else {
                ContentUnavailableView("Select a Pokémon", systemImage: "square.grid.3x3.fill")
                    .font(.pixel14)
                    .applyPokedexStyling(title: "")
            }
        }
    }
}

/// Pokedex toolbar with grid toggle and sort menu.
private struct PokedexToolbar<ViewModel: PokedexViewModelProtocol>: ToolbarContent {
    @State var viewModel: ViewModel

    var body: some ToolbarContent {
        ToolbarItem { gridLayoutButton }
        ToolbarItem { sortMenu }
        ToolbarItem { favourites }
    }

    private var gridLayoutButton: some View {
        Button("Change grid layout", systemImage: viewModel.grid.otherIcon) {
            withAnimation(.bouncy(duration: 0.25)) { viewModel.grid.toggle() }
        }
        .labelStyle(.iconOnly)
    }

    private var favourites: some View {
        Button(Tabs.favourites.title, systemImage: Tabs.favourites.icon) {
            viewModel.openFavourites.toggle()
        }
        .labelStyle(.iconOnly)
    }

    private var sortMenu: some View {
        Menu {
            Button(viewModel.sortDirection.label, systemImage: viewModel.sortDirection.systemImage) {
                viewModel.sortDirection.toggle()
            }

            Divider()

            Picker(selection: $viewModel.sortTypeResettingDirection) {
                ForEach(SortType.allCases, id: \.self) { type in
                    Label(type.title, systemImage: type.systemImage)
                        .tag(type)
                }
            } label: {
                Text("Sort by")
            }
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
        }
    }
}
