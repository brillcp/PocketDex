import SwiftUI
import SwiftData
import PokeBattleKit

/// Pokemon detail view model protocol.
@MainActor
protocol PokemonDetailViewModelProtocol {
    /// Display-ready data for the focused pokemon.
    var pokemon: PokemonViewModel { get }
    /// Whether this Pokémon is on "My team", mirrored from SwiftData.
    var isOnTeam: Bool { get }
    /// Front sprite image once loaded, otherwise `nil`.
    var sprite: Image? { get }
    /// Dominant color extracted from the sprite, used as accent.
    var color: Color? { get }
    /// Resolved evolution chain stages; empty until `loadEvolutionChain` runs.
    var evolutionStages: [EvolutionChain.Stage] { get }
    /// For the type chart section; `nil` while the battle catalogue loads.
    var typeChart: TypeChart? { get }

    /// Load front sprite image and extract dominant color.
    func loadSpritesAndColor() async
    /// Fetch evolution chain from cache or network.
    func loadEvolutionChain() async
    /// Add to or remove from "My team" on disk.
    func toggleTeamMembership()
    /// Play the pokemon's cry audio.
    func playCry() async
    /// Fetch a Pokemon by species id for evolution navigation.
    func pokemonForEvolution(speciesId: Int) -> Pokemon?
}

/// Concrete implementation of `PokemonDetailViewModelProtocol`.
///
/// Created by the presenting view and owned by `PokemonDetailView` as
/// `@State`. It's given only the services it uses; sprite download and
/// color analysis run inside those services, and only the finished `Image`
/// and `Color` are assigned here on the main actor.
@MainActor
@Observable
final class PokemonDetailViewModel {
    private let evolutionService: EvolutionServiceProtocol
    private let spriteLoader: SpriteLoading
    private let imageColorAnalyzer: ImageColorAnalyzing
    private let audioPlayer: AudioPlaying
    private let battleCatalog: any BattleCatalogReading
    private let modelContext: ModelContext

    var pokemon: PokemonViewModel
    var isOnTeam: Bool
    var sprite: Image?
    var color: Color?
    var evolutionStages: [EvolutionChain.Stage] = []

    init(
        summary: Pokemon,
        modelContext: ModelContext,
        evolutionService: EvolutionServiceProtocol,
        spriteLoader: SpriteLoading,
        imageColorAnalyzer: ImageColorAnalyzing,
        audioPlayer: AudioPlaying,
        battleCatalog: any BattleCatalogReading
    ) {
        self.isOnTeam = summary.isBookmarked
        self.pokemon = PokemonViewModel(pokemon: summary)
        self.evolutionService = evolutionService
        self.spriteLoader = spriteLoader
        self.imageColorAnalyzer = imageColorAnalyzer
        self.audioPlayer = audioPlayer
        self.battleCatalog = battleCatalog
        self.modelContext = modelContext
    }
}

// MARK: - PokemonDetailViewModelProtocol

extension PokemonDetailViewModel: PokemonDetailViewModelProtocol {
    var typeChart: TypeChart? { battleCatalog.typeChart }

    func loadEvolutionChain() async {
        guard evolutionStages.isEmpty,
              let chainId = pokemon.evolutionChainId
        else { return }
        guard let chain = try? await evolutionService.requestChain(id: "\(chainId)") else { return }
        evolutionStages = chain.stages
    }

    func loadSpritesAndColor() async {
        guard let image = await spriteLoader.spriteImage(from: pokemon.frontSprite) else { return }
        sprite = Image(uiImage: image)
        if color == nil, let color = await imageColorAnalyzer.dominantColor(for: pokemon.id, image: image) {
            self.color = color
        }
    }

    /// Re-fetches the model by id in the main context rather than holding
    /// on to it, then mirrors the new value into the display snapshot.
    func toggleTeamMembership() {
        let id = pokemon.id
        let descriptor = FetchDescriptor<Pokemon>(predicate: #Predicate { $0.id == id })
        guard let model = try? modelContext.fetch(descriptor).first else { return }
        model.isBookmarked.toggle()
        pokemon.isOnTeam = model.isBookmarked
        isOnTeam = model.isBookmarked
        try? modelContext.save()
    }

    func playCry() async {
        guard let cryURL = pokemon.latestCry else { return }
        await audioPlayer.play(from: cryURL)
    }

    func pokemonForEvolution(speciesId: Int) -> Pokemon? {
        let descriptor = FetchDescriptor<Pokemon>(predicate: #Predicate { $0.id == speciesId })
        return try? modelContext.fetch(descriptor).first
    }
}
