import SwiftUI
import SwiftData

/// Screens pushed onto the pokedex navigation stack. One route type, so
/// every push in the stack goes through its path (mixing path pushes with
/// `navigationDestination(isPresented:)` froze the app).
enum PokedexRoute: Hashable {
    case pokemon(Pokemon)
    case myTeam
}

/// Pokedex tab grid. Wraps `PokemonGrid` with color-analyzed cells,
/// navigation destinations, and a loading overlay for first-launch fetch.
struct PokedexGridView: View {
    @Namespace private var namespace
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext

    let pokemon: [Pokemon]
    var grid: GridLayout = .three
    var isLoading: Bool = false
    var loadingProgress: Double = 0
    /// When set, taps write to this binding instead of pushing the detail
    /// view (used by the side-by-side layout in regular width).
    var selection: Binding<Pokemon?>? = nil

    var body: some View {
        PokemonGrid(
            pokemon: pokemon,
            grid: grid,
            contentPadding: .init(top: DesignKit.Spacing.Primitive.s2, leading: DesignKit.Spacing.Primitive.s0, bottom: DesignKit.Spacing.Primitive.s2, trailing: DesignKit.Spacing.Primitive.s0)
        ) { pokemon in
            PokedexGridItem(
                pokemon: pokemon,
                grid: grid,
                namespace: namespace,
                isSelected: selection?.wrappedValue?.id == pokemon.id,
                selection: selection
            )
        }
        .overlay {
            if isLoading && pokemon.isEmpty {
                IndexingOverlay(progress: loadingProgress)
            }
        }
        .navigationDestination(for: PokedexRoute.self) { route in
            switch route {
            case .pokemon(let pokemon):
                PokemonDetailView(
                    viewModel: PokemonDetailViewModel(
                        summary: pokemon,
                        container: container,
                        modelContext: modelContext
                    )
                )
                .navigationTransition(.zoom(sourceID: pokemon.id, in: namespace))
            case .myTeam:
                MyTeamView()
            }
        }
    }
}

/// Full-screen progress overlay shown during first-load API fetch.
private struct IndexingOverlay: View {
    let progress: Double

    var body: some View {
        VStack(spacing: DesignKit.Spacing.Primitive.s16) {
            PixelSpinner()
                .opacity(progress >= 1.0 ? 1.0 : 0.0)
            ProgressView(value: progress)
                .tint(.pokedexRed)
                .frame(width: 200)
            Text("Loading Pokedex \(progress, format: .pixelPercent(rounding: .down))")
                .font(.pixel14)
                .foregroundStyle(.secondary)
        }
    }
}

/// Single cell in the pokedex grid with sprite and color-tinted background.
private struct PokedexGridItem: View {
    @Environment(\.container) private var container

    @State private var color: Color?
    @State private var isLight = false

    let pokemon: Pokemon
    let grid: GridLayout
    let namespace: Namespace.ID
    var isSelected = false
    /// Set in regular width: taps select instead of pushing. A binding (not
    /// a closure) so unchanged cells keep equal inputs and skip re-rendering.
    var selection: Binding<Pokemon?>?

    var body: some View {
        if let selection {
            Button { selection.wrappedValue = pokemon } label: { card }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink(value: PokedexRoute.pokemon(pokemon)) { card }
        }
    }

    private var card: some View {
        SpriteImage(url: pokemon.frontSprite, style: .plain) { uiImage in
            guard let resolved = await container.imageColorAnalyzer.dominantColor(for: pokemon.id, image: uiImage)
            else { return }
            isLight = resolved.isLight
            withAnimation(.easeInOut(duration: 0.2)) {
                color = resolved
            }
        }
        .background { color }
        .overlay {
            if grid == .three {
                CardOverlay(
                    id: pokemon.id,
                    name: pokemon.name,
                    isLight: isLight
                )
            }
        }
        .overlay {
            Rectangle()
                .strokeBorder(.white, lineWidth: 3)
                .opacity(isSelected ? 1 : 0)
        }
        .font(.pixel12)
        .matchedTransitionSource(id: pokemon.id, in: namespace)
    }
}

/// Id pill and name overlaid on the sprite cell.
private struct CardOverlay: View {
    let id: Int
    let name: String
    let isLight: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("#\(id)")
            }
            .padding(DesignKit.Spacing.Primitive.s8)
            Spacer()
            Text(name)
        }
        .padding(.bottom, DesignKit.Spacing.Primitive.s12)
        .foregroundStyle(isLight ? Color.darkGrey : .white)
    }
}
