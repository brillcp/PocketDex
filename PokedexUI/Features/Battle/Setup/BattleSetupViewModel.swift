import Foundation
import SwiftData
import SwiftUI
import PokeBattleKit

/// Discrete states the setup screen moves through.
///
/// Derived from the view model's inputs rather than stored, so it can never
/// disagree with them.
enum BattleSetupPhase: Equatable {
    /// Building display data and move pools.
    case loading
    /// Player is choosing; fewer than four moves selected.
    case picking
    /// Waiting for the AI to choose the opponent's loadout.
    case awaitingAI
    /// Player's four moves are in; "Start" asks the AI for its loadout.
    case readyToRequest
    /// Both loadouts are set; the view pushes the battle.
    case readyToStart
}

/// Pre-battle loadout preparation protocol.
@MainActor
protocol BattleSetupViewModelProtocol {
    var playerSummary:   Pokemon { get }
    var opponentSummary: Pokemon { get }
    var playerPokemon:   PokemonViewModel? { get }
    var opponentPokemon: PokemonViewModel? { get }
    var selection: MoveSelection { get }
    var opponentLoadout: [Move]? { get }
    var errorMessage: String? { get }
    var phase: BattleSetupPhase { get }

    func prepare() async
    /// Asks the AI for its loadout at `difficulty`.
    func requestOpponentLoadout(difficulty: Difficulty) async
}

/// Concrete implementation of `BattleSetupViewModelProtocol`.
@MainActor
@Observable
final class BattleSetupViewModel {
    private var opponentPool: [Move] = []
    private let aiService:    BattleAIServiceProtocol
    private let rules:        BattleRules

    let playerSummary:   Pokemon
    let opponentSummary: Pokemon
    let selection = MoveSelection()

    var playerPokemon:    PokemonViewModel?
    var opponentPokemon:  PokemonViewModel?
    var opponentLoadout:  [Move]?
    var errorMessage: String?
    private(set) var isPickingLoadout: Bool = false

    init(
        player: Pokemon,
        opponent: Pokemon,
        aiService: BattleAIServiceProtocol,
        rules: BattleRules
    ) {
        self.playerSummary   = player
        self.opponentSummary = opponent
        self.aiService       = aiService
        self.rules           = rules
    }
}

// MARK: - BattleSetupViewModelProtocol

extension BattleSetupViewModel: BattleSetupViewModelProtocol {
    var phase: BattleSetupPhase {
        guard playerPokemon != nil,
              opponentPokemon != nil,
              !selection.pool.isEmpty
        else { return .loading }
        guard selection.isFull else { return .picking }
        if isPickingLoadout { return .awaitingAI }
        if opponentLoadout != nil { return .readyToStart }
        return .readyToRequest
    }

    func prepare() async {
        let player   = PokemonViewModel(pokemon: playerSummary)
        let opponent = PokemonViewModel(pokemon: opponentSummary)
        self.playerPokemon   = player
        self.opponentPokemon = opponent

        let playerMoves   = MoveSelection.movesForPokemon(player.pokemon)
        let opponentMoves = MoveSelection.movesForPokemon(opponent.pokemon)

        guard !playerMoves.isEmpty else {
            errorMessage = "Couldn't load \(playerSummary.name)'s movepool. Check your connection and try again."
            return
        }
        guard !opponentMoves.isEmpty else {
            errorMessage = "Couldn't load \(opponentSummary.name)'s movepool. Check your connection and try again."
            return
        }

        // Best moves for this matchup first, then the recommended loadout
        // pre-selected, so the strongest swaps sit right below it.
        let fighter = Combatant(pokemon: player, moves: [], rules: rules)
        let foe = Combatant(pokemon: opponent, moves: [], rules: rules)
        let chart = PokeBattleKit.typeChart
        selection.load(ranked: LoadoutStrategy.shortlist(
            fighter: fighter, opponent: foe, moves: playerMoves, typeChart: chart, limit: playerMoves.count
        ))
        selection.recommend(LoadoutStrategy.heuristicPick(fighter: fighter, opponent: foe, moves: playerMoves, typeChart: chart))
        self.opponentPool = opponentMoves
    }

    /// Picked after the player locks in, so the AI can counter the player's
    /// actual moves.
    func requestOpponentLoadout(difficulty: Difficulty) async {
        guard let player = playerPokemon,
              let opponent = opponentPokemon else { return }

        isPickingLoadout = true
        let chart   = PokeBattleKit.typeChart
        let fighter = Combatant(pokemon: opponent, moves: [], rules: rules, level: rules.opponentLevel(for: difficulty))
        let foe     = Combatant(pokemon: player,  moves: [], rules: rules)
        let chosen  = selection.selectedMoves

        let picks = await aiService.chooseLoadout(
            for: fighter,
            against: foe,
            moves: opponentPool,
            playerMoves: chosen,
            typeChart: chart,
            difficulty: difficulty
        )

        guard !picks.isEmpty else {
            errorMessage = "Opponent couldn't pick a loadout."
            isPickingLoadout = false
            return
        }
        withAnimation(DesignKit.Animation.Primitive.easeInOut25) {
            self.opponentLoadout = picks
        }
        isPickingLoadout = false
    }
}
