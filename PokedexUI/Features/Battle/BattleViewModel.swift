import SwiftUI
import PokeBattleKit

/// Drives `BattleView` as a conductor over engine, animator, log, and audio.
///
/// Two conformers: `BattleViewModel` (local `BattleEngine` vs. AI) and
/// `MultiplayerBattleViewModel` (events resolved by the host peer). Both
/// apply events through `BattleStateReducer` and cue the same
/// `BattleAnimator`, so the screen behaves identically either way.
@MainActor
protocol BattleViewModelProtocol: AnyObject {
    var playerName: String { get }
    var opponentName: String { get }
    var animator: BattleAnimator { get }
    var state: BattleState? { get }
    /// Whether a move can be chosen right now: the battle is ready with no
    /// error, no turn is playing, there's no winner yet, and (in
    /// multiplayer) no move is already committed.
    var canSelectMove: Bool { get }
    var log: [BattleLogEntry] { get }
    var isResolvingTurn: Bool { get }
    var winner: Side? { get }
    var errorMessage: String? { get }
    var displayMoves: [Move] { get }

    /// Entrance animation, sprite colors, and any setup; run from `.task`.
    func prepare() async
    /// Play one turn with the player's `move`, animating events in order.
    func submit(_ move: Move) async

    /// The battle's type chart; `nil` if the catalogue hadn't loaded.
    var typeChart: TypeChart? { get }
    /// Type effectiveness of `move` against current opponent.
    func effectiveness(for move: Move) -> Double?
}

extension BattleViewModelProtocol {
    func effectiveness(for move: Move) -> Double? {
        guard let types = state?.opponent.typeNames, !types.isEmpty else { return nil }
        return typeChart?.multiplier(attacking: move.typeName, defenders: types)
    }
}

/// Concrete `BattleViewModelProtocol` implementation for single-player
/// battles against an AI opponent.
///
/// Each turn: ask `BattleAIDriver` for the opponent's move (PokeBattleKit's
/// rule-based AI), resolve the round synchronously with the value-type
/// `BattleEngine`, then replay the resulting events one by one: format a log
/// line, reduce into `state`, and await the matching animation.
@MainActor
@Observable
final class BattleViewModel {
    private let opponentMoves: [Move]
    private let playerMoves:   [Move]
    private let formatter:     BattleLogFormatter
    private let aiDriver:     BattleAIDriver
    private let spriteColors:  SpriteColorResolver
    private let eventPlayer:   BattleEventPlayer
    private(set) var typeChart: TypeChart?

    let playerPokemon:   PokemonViewModel
    let opponentPokemon: PokemonViewModel
    let animator:        BattleAnimator
    let displayMoves:    [Move]

    /// Authoritative battle state. `state` is the displayed copy that events
    /// are reduced into while they animate, then reset to the engine's.
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
        difficulty: Difficulty,
        aiService: any MoveChoosing,
        services: BattleServices
    ) {
        self.playerPokemon   = player
        self.opponentPokemon = opponent
        self.displayMoves    = playerMoves
        self.playerMoves     = playerMoves
        self.opponentMoves   = opponentMoves
        self.aiDriver        = BattleAIDriver(service: aiService, difficulty: difficulty)
        self.spriteColors    = SpriteColorResolver(
            spriteLoader: services.spriteLoader,
            imageColorAnalyzer: services.imageColorAnalyzer
        )
        let animator = BattleAnimator()
        let formatter = BattleLogFormatter(
            playerName: player.name,
            opponentName: opponent.name
        )
        self.animator = animator
        self.formatter = formatter
        self.eventPlayer = BattleEventPlayer(
            formatter: formatter,
            animator: animator,
            audioPlayer: services.audioPlayer,
            playerCry: player.latestCry,
            opponentCry: opponent.latestCry
        )
        // Same rules for both sides and no HP edge for the player. The
        // difficulty sets the opponent's level, the classic way: below the
        // player's on easy, equal on fair, above on hard.
        let p = Combatant(
            pokemon: player,
            moves: playerMoves.map { MoveSnapshot(from: $0) },
            rules: services.rules
        )
        let o = Combatant(
            pokemon: opponent,
            moves: opponentMoves.map { MoveSnapshot(from: $0) },
            rules: services.rules,
            level: services.rules.opponentLevel(for: difficulty)
        )
        let initialState = BattleState(player: p, opponent: o)
        self.state = initialState
        // Read without trapping: if the battle catalogue hasn't loaded, the
        // battle can't start and says so instead of crashing.
        if let chart = services.catalog.typeChart {
            activateEngine(state: initialState, chart: chart)
        } else {
            errorMessage = Localized("battle.error.dataNotLoaded")
        }
    }
}

// MARK: - BattleViewModelProtocol
extension BattleViewModel: BattleViewModelProtocol {
    var playerName: String { playerPokemon.name }
    var opponentName: String { opponentPokemon.name }
    var canSelectMove: Bool { engine != nil && errorMessage == nil && !isResolvingTurn && winner == nil }

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
        guard canSelectMove, var eng = engine, let typeChart, let snapshot = state else { return }
        animator.attackTick += 1
        isResolvingTurn = true

        // "..." while the AI thinks; removed once its move is in.
        log.append(.placeholder)

        let opponentMove = await aiDriver.nextOpponentMove(
            attacker: snapshot.opponent,
            defender: snapshot.player,
            opponentMoves: opponentMoves,
            playerMoves: playerMoves,
            typeChart: typeChart
        )

        withAnimation(DesignKit.Animation.Primitive.easeOut25) {
            log.removeAll { $0.kind == .placeholder }
        }

        // Only when the opponent has no moves and Struggle isn't loaded.
        guard let opponentMove else {
            errorMessage = Localized("battle.error.dataNotLoaded")
            isResolvingTurn = false
            return
        }

        // `BattleEngine` is a struct: mutate a copy, then store it back.
        let events = eng.resolveRound(playerMove: move, opponentMove: opponentMove)
        self.engine = eng

        await eventPlayer.play(events, into: self)
        // Re-sync with the engine so bookkeeping the reducer doesn't mirror
        // (sleep counters, recharge flags) can't drift from the display.
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
        await eventPlayer.playEntrance(into: self, announcement: formatter.wildAppeared)
    }
}

extension BattleViewModel: BattleEventSink {}
