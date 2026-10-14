import SwiftUI
import PokeBattleKit

/// Drives `BattleView` as a conductor over engine, animator, log, and audio.
@MainActor
protocol BattleViewModelProtocol: AnyObject {
    var playerName: String { get }
    var opponentName: String { get }
    var animator: BattleAnimator { get }
    var state: BattleState? { get }
    var canSelectMove: Bool { get }
    var log: [BattleLogEntry] { get }
    var isResolvingTurn: Bool { get }
    var winner: Side? { get }
    var errorMessage: String? { get }
    var displayMoves: [Move] { get }

    func prepare() async
    func submit(_ move: Move) async

    /// Type effectiveness of `move` against current opponent.
    func effectiveness(for move: Move) -> Double?
}

extension BattleViewModelProtocol {
    func effectiveness(for move: Move) -> Double? {
        guard let types = state?.opponent.typeNames, !types.isEmpty else { return nil }
        return PokeBattleKit.typeChart.multiplier(attacking: move.typeName, defenders: types)
    }
}

/// Concrete `BattleViewModelProtocol` implementation.
@MainActor
@Observable
final class BattleViewModel {
    private let opponentMoves: [Move]
    private let playerMoves:   [Move]
    private let formatter:     BattleLogFormatter
    private let audioPlayer:   AudioPlaying
    private let aiDriver:      BattleAIDriver
    private let spriteColors:  SpriteColorResolver
    private var typeChart:     TypeChart?

    let playerPokemon:   PokemonViewModel
    let opponentPokemon: PokemonViewModel
    let animator:        BattleAnimator
    let displayMoves:    [Move]

    private var engine: BattleEngine?
    var state:  BattleState?
    var log:    [BattleLogEntry] = []
    var isResolvingTurn  = false
    var winner: Side?
    var errorMessage: String?

    init(
        player: PokemonViewModel,
        opponent: PokemonViewModel,
        playerMoves: [Move],
        opponentMoves: [Move],
        container: AppContainer
    ) {
        self.playerPokemon   = player
        self.opponentPokemon = opponent
        self.displayMoves    = playerMoves
        self.playerMoves     = playerMoves
        self.opponentMoves   = opponentMoves
        self.audioPlayer     = container.audioPlayer
        self.aiDriver        = BattleAIDriver(service: container.battleAI)
        self.spriteColors    = SpriteColorResolver(
            spriteLoader: container.spriteLoader,
            imageColorAnalyzer: container.imageColorAnalyzer
        )
        self.animator = BattleAnimator()
        self.formatter = BattleLogFormatter(
            playerName: player.name,
            opponentName: opponent.name
        )
        let p = Combatant(
            pokemon: player,
            moves: playerMoves.map { MoveSnapshot(from: $0) },
            hpBonus: 1.2
        )
        let o = Combatant(
            pokemon: opponent,
            moves: opponentMoves.map { MoveSnapshot(from: $0) }
        )
        let initialState = BattleState(player: p, opponent: o)
        self.state = initialState
        let chart = PokeBattleKit.typeChart
        activateEngine(state: initialState, chart: chart)
    }
}

// MARK: - BattleViewModelProtocol
extension BattleViewModel: BattleViewModelProtocol {
    var playerName: String { playerPokemon.name }
    var opponentName: String { opponentPokemon.name }
    var canSelectMove: Bool { engine != nil }

    func prepare() async {
        // Sendable values only: `async let` evaluates in a child task.
        let playerID = playerPokemon.id
        let playerSpriteURL = playerPokemon.frontSprite
        let opponentID = opponentPokemon.id
        let opponentSpriteURL = opponentPokemon.frontSprite
        async let entrance: Void = playEntrance()
        async let colors: Void = spriteColors.resolve(
            playerID: playerID,
            playerSpriteURL: playerSpriteURL,
            opponentID: opponentID,
            opponentSpriteURL: opponentSpriteURL,
            animator: animator
        )
        _ = await (entrance, colors)
    }

    func submit(_ move: Move) async {
        guard var eng = engine, let typeChart, !isResolvingTurn, winner == nil, let snapshot = state else { return }
        animator.attackTick += 1
        isResolvingTurn = true

        log.append(.placeholder)

        let opponentMove = await aiDriver.nextOpponentMove(
            attacker: snapshot.opponent,
            defender: snapshot.player,
            opponentMoves: opponentMoves,
            playerMoves: playerMoves,
            typeChart: typeChart
        )

        withAnimation(.easeOut(duration: 0.25)) {
            log.removeAll { $0.kind == .placeholder }
        }

        let events = eng.resolveRound(playerMove: move, opponentMove: opponentMove)
        self.engine = eng

        for event in events {
            let line = formatter.format(event, playerColor: animator.playerCues.color, opponentColor: animator.opponentCues.color)
            log.append(.regular(line))
            #if DEBUG
            print("⚔️ \(String(line.characters))")
            #endif
            apply(event)
            await animator.play(event)
            try? await Task.sleep(for: .milliseconds(650))
            if case .ended(let w) = event {
                winner = w ?? .player
                await playWinnerCry()
                break
            }
        }
        state = eng.state
        aiDriver.recordPlayerUsed(move.name, in: events)
        isResolvingTurn = false
    }
}

// MARK: - Private
private extension BattleViewModel {

    func activateEngine(state: BattleState, chart: TypeChart) {
        self.typeChart = chart
        self.engine = BattleEngine(state: state, typeChart: chart)
    }

    func playEntrance() async {
        await animator.playEntrance()
        log.append(.regular(formatter.wildAppeared(opponentColor: animator.opponentCues.color)))

        if let cry = opponentPokemon.latestCry {
            await audioPlayer.play(from: cry)
        }
    }

    func playWinnerCry() async {
        guard let winner else { return }
        let cry = winner == .player ? playerPokemon.latestCry : opponentPokemon.latestCry
        guard let cry else { return }
        try? await Task.sleep(for: .milliseconds(350))
        await audioPlayer.play(from: cry)
    }

    func apply(_ event: Event) {
        guard var snapshot = state else { return }
        BattleStateReducer.apply(event, to: &snapshot, animator: animator)
        state = snapshot
    }
}
