import Foundation
import SwiftData
import SwiftUI
import PokeBattleKit

/// Discrete states the setup screen moves through.
enum BattleSetupPhase: Equatable {
    case loading
    case picking
    case awaitingAI
    case readyToRequest
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
    func requestOpponentLoadout() async
}

/// Concrete implementation of `BattleSetupViewModelProtocol`.
@MainActor
@Observable
final class BattleSetupViewModel {
    private var opponentPool: [Move] = []
    private let aiService:    BattleAIServiceProtocol

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
        aiService: BattleAIServiceProtocol
    ) {
        self.playerSummary   = player
        self.opponentSummary = opponent
        self.aiService       = aiService
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

        guard playerMoves.count >= selection.maxSelections else {
            errorMessage = "Couldn't load \(playerSummary.name)'s movepool. Check your connection and try again."
            return
        }
        guard opponentMoves.count >= selection.maxSelections else {
            errorMessage = "Couldn't load \(opponentSummary.name)'s movepool. Check your connection and try again."
            return
        }

        selection.load(ranked: playerMoves)
        self.opponentPool = opponentMoves
    }

    func requestOpponentLoadout() async {
        guard let player = playerPokemon,
              let opponent = opponentPokemon else { return }

        isPickingLoadout = true
        let chart   = PokeBattleKit.typeChart
        let fighter = Combatant(pokemon: opponent, moves: [])
        let foe     = Combatant(pokemon: player,  moves: [])
        let chosen  = selection.selectedMoves

        let picks = await aiService.chooseLoadout(
            for: fighter,
            against: foe,
            moves: opponentPool,
            playerMoves: chosen,
            typeChart: chart
        )

        guard picks.count >= selection.maxSelections else {
            errorMessage = "Opponent couldn't pick a loadout."
            isPickingLoadout = false
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            self.opponentLoadout = picks
        }
        isPickingLoadout = false
    }
}
