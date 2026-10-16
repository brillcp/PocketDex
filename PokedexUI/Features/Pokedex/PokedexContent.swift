import SwiftUI
import SwiftData

/// Pokedex tab content with grid and toolbar.
///
/// In compact width (iPhone, folded iPhone Duo) the grid pushes the detail
/// view onto a single stack. In regular width (unfolded iPhone Duo, iPad,
/// wide windows) the detail sits in a leading column and the grid in a
/// trailing column. The layout follows the size class rather than the
/// device, so it adapts live as the window resizes or the device folds.
///
/// The regular layout is a plain `HStack` of two `NavigationStack`s rather
/// than a `NavigationSplitView`, because the split view can only place its
/// sidebar on the leading edge and the grid is meant to sit on the right.
/// The open Pokémon lives in `path` (compact) or `selection` (regular), and
/// an open "My team" in `path` or `columnPath`; both are moved across
/// whenever the size class changes.
struct PokedexContent<ViewModel: PokedexViewModelProtocol>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let viewModel: ViewModel

    /// Pushed screens in compact width.
    @State private var path: [PokedexRoute] = []
    /// Detail shown in the leading column in regular width.
    @State private var selection: Pokemon?
    /// Screens pushed in the grid column in regular width ("My team").
    @State private var columnPath: [PokedexRoute] = []

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
        // Carry the open Pokémon and "My team" across fold/unfold so they
        // stay on screen.
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .regular {
                for case .pokemon(let pokemon) in path { selection = pokemon }
                columnPath = path.contains(.myTeam) ? [.myTeam] : []
                path = []
            } else {
                path = columnPath + (selection.map { [.pokemon($0)] } ?? [])
                columnPath = []
            }
        }
    }

    private var sideBySide: some View {
        HStack(spacing: DesignKit.Spacing.Primitive.s0) {
            PokedexDetailColumn(selection: selection)
                // New identity per selection: fresh detail state and a reset
                // stack (evolutions, type lists, battles pushed inside it).
                .id(selection?.id)

            Divider()

            NavigationStack(path: $columnPath) {
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
            onRetry: viewModel.loadFailed ? { retry() } : nil,
            selection: selection
        )
        .applyPokedexStyling(title: Tabs.pokedex.title)
        .toolbar { PokedexToolbar(viewModel: viewModel) }
        .animation(DesignKit.Animation.Primitive.snappy25, value: viewModel.sortType)
        .animation(DesignKit.Animation.Primitive.snappy25, value: viewModel.sortDirection)
    }

    func retry() {
        Task { await viewModel.requestPokemon() }
    }
}

/// Leading column in regular width: the selected Pokémon's detail, or a
/// placeholder (untitled, so only the grid column shows the app title).
private struct PokedexDetailColumn: View {

    let selection: Pokemon?

    var body: some View {
        NavigationStack {
            if let selection {
                PokemonDetailScreen(pokemon: selection)
            } else {
                ContentUnavailableView("pokedex.nothingSelected", systemImage: "square.grid.3x3.fill")
                    .font(.pixel14)
                    .applyPokedexStyling(title: "")
            }
        }
    }
}

/// Pokedex toolbar with grid toggle and sort menu.
///
/// Holds the view model in `@State` only to get `$viewModel` bindings for the
/// sort picker; the parent passes the same long-lived reference each time.
private struct PokedexToolbar<ViewModel: PokedexViewModelProtocol>: ToolbarContent {
    @State var viewModel: ViewModel

    var body: some ToolbarContent {
        ToolbarItem { gridLayoutButton }
        ToolbarItem { sortMenu }
        ToolbarItem { myTeam }
    }

    private var gridLayoutButton: some View {
        Button("pokedex.toolbar.gridLayout", systemImage: viewModel.grid.otherIcon) {
            withAnimation(DesignKit.Animation.Primitive.bouncy25) { viewModel.grid.toggle() }
        }
        .labelStyle(.iconOnly)
    }

    private var myTeam: some View {
        NavigationLink(value: PokedexRoute.myTeam) {
            Label(MyTeam.title, systemImage: MyTeam.icon)
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
                Text("pokedex.toolbar.sortBy")
            }
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
        }
    }
}
