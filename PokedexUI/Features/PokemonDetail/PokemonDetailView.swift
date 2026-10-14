import SwiftUI
import SwiftData

/// Pokemon detail screen with stats, evolution, weaknesses, and battle entry.
///
/// Navigation out of the screen (evolutions, type lists, battles) is
/// item-driven local state, so the same view works inside any parent
/// `NavigationStack`: the compact pokedex stack, the regular-width detail
/// column, search, and bookmarks.
struct PokemonDetailView<ViewModel: PokemonDetailViewModelProtocol>: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: ViewModel
    @State private var showOpponentPicker = false
    @State private var battleLaunch: BattleLaunch?
    @State private var evolutionTarget: Pokemon?
    @State private var selectedType: String?
    /// Written on every scroll frame; only `DetailSpriteBackdrop` reads it
    /// (through a binding), so the rest of the body isn't re-evaluated.
    @State private var spriteBlur: CGFloat = 0

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignKit.Spacing.Primitive.s16) {
                // Reserve room for the backdrop sprite, which stays fixed
                // behind the content and blurs as it scrolls over it.
                Spacer().frame(height: 320)
                loadedContent(pokemon: viewModel.pokemon)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, offset in
            // No blur for the first 160pt, then ramp up to a 32pt cap.
            spriteBlur = min(32, max(0, (offset - 160) / 12))
        }
        .background {
            DetailSpriteBackdrop(
                sprite: viewModel.sprite,
                blurRadius: $spriteBlur
            )
        }
        .background {
            MeshGradientBackground(color: viewModel.color ?? .darkGrey)
                .ignoresSafeArea()
        }
        .scrollIndicators(.hidden)
        .task(id: viewModel.pokemon.id) {
            await viewModel.loadSpritesAndColor()
        }
        .task(id: viewModel.pokemon.evolutionChainId) {
            await viewModel.loadEvolutionChain()
        }
        .sheet(isPresented: $showOpponentPicker) {
            OpponentPickerView(
                player: viewModel.pokemon.pokemon,
                playerTypes: viewModel.pokemon.typeNames
            ) { launch in
                showOpponentPicker = false
                battleLaunch = launch
            }
        }
        .navigationDestination(item: $battleLaunch) { launch in
            BattleView(viewModel: launch.viewModel)
        }
        .navigationDestination(item: $selectedType) { typeName in
            TypePokemonListView(typeName: typeName)
        }
        .navigationDestination(item: $evolutionTarget) { target in
            PokemonDetailView<PokemonDetailViewModel>(
                viewModel: PokemonDetailViewModel(
                    summary: target,
                    container: container,
                    modelContext: modelContext
                )
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.toggleBookmark()
                } label: {
                    Image(systemName: viewModel.isBookmarked ? "heart.fill" : "heart")
                        .foregroundStyle(textColor)
                }
            }
        }
        .applyPokedexStyling(
            title: "\(viewModel.pokemon.name) #\(viewModel.pokemon.id)",
            navColor: .clear,
            titleColor: textColor,
            background: nil
        )
    }
}

// MARK: - Private
private extension PokemonDetailView {
    var textColor: Color {
        viewModel.color?.isLight ?? false ? Color.darkGrey : .white
    }

    func loadedContent(pokemon: PokemonViewModel) -> some View {
        VStack(spacing: DesignKit.Spacing.Primitive.s32) {
            actionButtons(pokemon: pokemon)
            SpeciesHeader(
                genus: pokemon.genus,
                generationLabel: pokemon.generationLabel,
                isLegendary: pokemon.isLegendary,
                isMythical: pokemon.isMythical,
                textColor: textColor
            )

            if let flavorText = pokemon.flavorText {
                DetailSection {
                    Text(flavorText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            DetailSection(title: "Data") {
                TypesRow(typeNames: pokemon.typeNames) { selectedType = $0 }
                DetailRow(title: "Height", subtitle: pokemon.height)
                DetailRow(title: "Weight", subtitle: pokemon.weight)

                if let habitat = pokemon.habitat {
                    DetailRow(title: "Habitat", subtitle: habitat)
                }
                DetailRow(title: "Capture", subtitle: pokemon.capturePercent)
                if pokemon.genderRate > 0 {
                    GenderRow(rate: pokemon.genderRate, textColor: textColor)
                }
            }

            DetailSection(title: "Type chart") {
                WeaknessGridView(
                    typeNames: pokemon.typeNames,
                    textColor: textColor,
                    onSelectType: { selectedType = $0 }
                )
            }
            DetailSection(title: "Moves / Abilities") {
                DetailRow(subtitle: pokemon.moves, axis: .vertical)
                DetailRow(subtitle: pokemon.abilities, axis: .vertical)
            }
            DetailSection(title: "Stats") {
                ForEach(pokemon.stats) { stat in
                    DetailRowStat(
                        title: stat.stat.name,
                        value: stat.baseStat,
                        textColor: textColor
                    )
                }
                HStack {
                    Text("Total")
                    Spacer()
                    Text("\(pokemon.baseStatTotal)")
                }
            }

            if viewModel.evolutionStages.count > 1 {
                DetailSection(title: "Evolution") {
                    EvolutionChainView(
                        stages: viewModel.evolutionStages,
                        textColor: textColor,
                        onSelect: navigateToEvolution
                    )
                }
            }
        }
        .padding(.bottom, DesignKit.Spacing.Primitive.s32)
        .foregroundStyle(textColor)
        .lineHeight(.loose)
        .font(.pixel14)
    }

    func navigateToEvolution(speciesId: Int) {
        guard speciesId != viewModel.pokemon.id else { return }
        evolutionTarget = viewModel.pokemonForEvolution(speciesId: speciesId)
    }

    func actionButtons(pokemon: PokemonViewModel) -> some View {
        HStack {
            if pokemon.latestCry != nil {
                DetailButton(icon: "speaker.wave.3.fill") {
                    Task { await viewModel.playCry() }
                }
            }
            Spacer()
            SecondaryCapsuleButton(icon: "bolt.fill", title: "Battle", color: textColor) {
                showOpponentPicker = true
            }
        }
        .tint(textColor)
        .padding(.horizontal, DesignKit.Spacing.Primitive.s24)
    }
}

// MARK: - Sprite Backdrop

/// Large sprite behind the scroll content. Takes the blur as a binding so
/// only this view, not the whole detail body, re-evaluates on every scroll
/// frame: the parent body never reads `spriteBlur`, so it isn't a dependency
/// of the parent.
private struct DetailSpriteBackdrop: View {
    let sprite: Image?
    @Binding var blurRadius: CGFloat

    var body: some View {
        VStack {
            sprite?
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 320)
                .blur(radius: blurRadius)
            Spacer()
        }
    }
}


#Preview {
    let container = try! ModelContainer(for: Pokemon.self, configurations: .init(isStoredInMemoryOnly: true))
    let vm = PokemonDetailViewModel(
        summary: .pikachu,
        container: .live,
        modelContext: container.mainContext
    )
    PokemonDetailView(viewModel: vm)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
