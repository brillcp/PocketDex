import SwiftUI
import SwiftData
import PokeBattleKit

/// Builds every screen's view model with exactly the services it needs.
///
/// The one place view models are wired to `AppContainer`, so views ask for
/// a view model (`viewModels.pokemonDetail(for:)`) instead of reaching into
/// the container for services. Reached through `Environment(\.viewModels)`.
struct ViewModelFactory: Sendable {
    let container: AppContainer
}

// MARK: - Screens
extension ViewModelFactory {
    @MainActor
    func pokedex() -> PokedexViewModel {
        PokedexViewModel(modelContext: modelContext, repository: container.repository)
    }

    @MainActor
    func items() -> ItemListViewModel {
        ItemListViewModel(modelContext: modelContext, repository: container.repository)
    }

    @MainActor
    func search() -> SearchViewModel {
        SearchViewModel(repository: container.repository)
    }

    @MainActor
    func pokemonDetail(for pokemon: Pokemon) -> PokemonDetailViewModel {
        PokemonDetailViewModel(
            summary: pokemon,
            modelContext: modelContext,
            evolutionService: container.evolutionService,
            spriteLoader: container.spriteLoader,
            imageColorAnalyzer: container.imageColorAnalyzer,
            audioPlayer: container.audioPlayer,
            battleCatalog: container.battleCatalog
        )
    }

    /// The fighter picker for challenging `opponent`, and the loadout screen
    /// it pushes for the chosen fighter.
    @MainActor
    func fighterPicker(against opponent: Pokemon, opponentTypes: [String]) -> FighterPickerViewModel {
        FighterPickerViewModel(
            opponent: opponent,
            opponentTypes: opponentTypes,
            repository: container.repository,
            aiService: container.battleAI,
            catalog: container.battleCatalog,
            makeSetup: { fighter in battleSetup(player: fighter, opponent: opponent) }
        )
    }

    @MainActor
    func battleSetup(player: Pokemon, opponent: Pokemon) -> BattleSetupViewModel {
        BattleSetupViewModel(
            player: player,
            opponent: opponent,
            aiService: container.battleAI,
            catalog: container.battleCatalog,
            movePools: movePools,
            rules: container.battleRules
        )
    }

    @MainActor
    func battle(
        player: PokemonViewModel,
        opponent: PokemonViewModel,
        playerMoves: [Move],
        opponentMoves: [Move],
        difficulty: Difficulty
    ) -> BattleViewModel {
        BattleViewModel(
            player: player,
            opponent: opponent,
            playerMoves: playerMoves,
            opponentMoves: opponentMoves,
            difficulty: difficulty,
            aiService: container.battleAI,
            services: container.battleServices
        )
    }

    /// The multiplayer lobby, its handshake, and the battle the handshake
    /// launches once both loadouts are in.
    @MainActor
    func multiplayerSetup() -> MultiplayerSetupViewModel {
        let handshake = MultiplayerHandshake(
            multipeer: container.multipeerService,
            catalog: container.battleCatalog,
            movePools: movePools,
            makeBattle: multiplayerBattle
        )
        return MultiplayerSetupViewModel(multipeer: container.multipeerService, handshake: handshake)
    }

    @MainActor
    func multiplayerBattle(_ match: MultiplayerHandshake.Match) -> MultiplayerBattleViewModel {
        MultiplayerBattleViewModel(
            role: match.role,
            selfSummary: match.selfSummary,
            selfMoves: match.selfMoves,
            peerSummary: match.peerSummary,
            peerMoves: match.peerMoves,
            multipeer: container.multipeerService,
            services: container.battleServices
        )
    }
}

// MARK: - Private
private extension ViewModelFactory {
    /// The UI reads through the container's main context; the app installs
    /// the same container in the scene, so it's the views' `modelContext`.
    @MainActor
    var modelContext: ModelContext { container.modelContainer.mainContext }

    @MainActor
    var movePools: MovePoolBuilder {
        MovePoolBuilder(catalog: container.battleCatalog, baseForms: StoreBaseFormLookup(modelContext: modelContext))
    }
}
