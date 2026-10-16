import SwiftUI
import PokeBattleKit

/// `BattleViewModelProtocol` implementation that runs a turn-based battle
/// across two devices over `MultipeerService`.
///
/// The turn protocol is PokeBattleKit's `PeerBattle`: the host runs the
/// engine and both devices play its resolved rounds (the guest's mirrored,
/// so its own pokemon is always `.player`), with turn numbers to ignore
/// stale messages. This view model feeds it moves and the peer's `.turn`
/// messages, and carries out the steps it returns: send, prompt, play.
@MainActor
@Observable
final class MultiplayerBattleViewModel {
    private let multipeer: any PeerMessaging
    private let formatter: BattleLogFormatter
    private let spriteColors: SpriteColorResolver
    private let eventPlayer: BattleEventPlayer
    private let selfSummary: PokemonSummary
    private let peerSummary: PokemonSummary
    private(set) var typeChart: TypeChart?
    /// `nil` if the catalogue hadn't loaded, so the battle can't start.
    private var battle: PeerBattle?
    private var listenTask: Task<Void, Never>?

    let animator: BattleAnimator
    let displayMoves: [Move]
    let playerName: String
    let opponentName: String

    var state: BattleState?
    var log: [BattleLogEntry] = []
    var isResolvingTurn: Bool = false
    var winner: Side?
    var errorMessage: String?

    init(
        role: PeerBattle.Role,
        selfSummary: PokemonSummary,
        selfMoves: [Move],
        peerSummary: PokemonSummary,
        peerMoves: [Move],
        multipeer: any PeerMessaging,
        services: BattleServices
    ) {
        self.multipeer = multipeer
        self.selfSummary = selfSummary
        self.peerSummary = peerSummary
        self.displayMoves = selfMoves
        self.playerName = selfSummary.name
        self.opponentName = peerSummary.name
        let animator = BattleAnimator()
        let formatter = BattleLogFormatter(
            playerName: selfSummary.name,
            opponentName: peerSummary.name
        )
        self.animator = animator
        self.formatter = formatter
        self.eventPlayer = BattleEventPlayer(
            formatter: formatter,
            animator: animator,
            audioPlayer: services.audioPlayer,
            playerCry: selfSummary.cryURL,
            opponentCry: peerSummary.cryURL
        )
        self.spriteColors = SpriteColorResolver(
            spriteLoader: services.spriteLoader,
            imageColorAnalyzer: services.imageColorAnalyzer
        )
        let selfCombatant = Combatant(
            pokemon: selfSummary,
            moves: selfMoves.map { MoveSnapshot(from: $0) },
            rules: services.rules
        )
        let peerCombatant = Combatant(
            pokemon: peerSummary,
            moves: peerMoves.map { MoveSnapshot(from: $0) },
            rules: services.rules
        )
        let initialState = BattleState(player: selfCombatant, opponent: peerCombatant)
        self.state = initialState
        // Both peers use the chart for effectiveness labels; only the host's
        // `PeerBattle` runs the engine.
        if let chart = services.catalog.typeChart {
            self.typeChart = chart
            self.battle = PeerBattle(role: role, state: initialState, typeChart: chart, peerMoves: peerMoves)
        } else {
            self.errorMessage = Localized("battle.error.dataNotLoaded")
        }
    }

    /// Ends the listen loop with the screen, rather than at the next event
    /// after deinit.
    isolated deinit {
        listenTask?.cancel()
    }
}

// MARK: - BattleViewModelProtocol
extension MultiplayerBattleViewModel: BattleViewModelProtocol {
    var canSelectMove: Bool {
        guard let battle else { return false }
        return battle.committedMove == nil && errorMessage == nil && winner == nil && !isResolvingTurn
    }

    func prepare() async {
        startListening()
        async let entrance: Void = playEntrance()
        async let colors: Void = spriteColors.resolve(
            playerID: selfSummary.id,
            playerSpriteURL: selfSummary.frontSprite,
            opponentID: peerSummary.id,
            opponentSpriteURL: peerSummary.frontSprite,
            animator: animator
        )
        _ = await (entrance, colors)
    }

    func submit(_ move: Move) async {
        guard canSelectMove, let steps = battle?.commit(move) else { return }

        animator.attackTick += 1
        log.append(.prompt(formatter.waitingForOpponent()))
        await perform(steps)
    }
}

// MARK: - Message handling
private extension MultiplayerBattleViewModel {
    /// Consumes the multipeer event stream for the lifetime of the screen.
    /// `[weak self]` lets the view model deinit when the battle is popped,
    /// and `deinit` cancels the task.
    func startListening() {
        guard listenTask == nil else { return }

        let stream = multipeer.events()
        listenTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                if case .message(let message) = event {
                    await self.handle(message)
                }
            }
        }
    }

    func handle(_ message: BattleMessage<PokemonSummary>) async {
        switch message {
        case .turn(let turn):
            guard let steps = battle?.receive(turn) else { return }
            await perform(steps)
        case .disconnect:
            // Leaving after the battle is decided is normal; keep the result.
            guard winner == nil else { return }
            errorMessage = Localized("multiplayer.error.disconnected")
        case .hello, .challengeProposed, .challengeAccepted, .challengeDeclined, .rematch:
            break
        }
    }

    /// Carries out `PeerBattle`'s steps in order. Its messages come before
    /// the round's events, so both devices play the round together.
    func perform(_ steps: [PeerBattle.Step]) async {
        for step in steps {
            switch step {
            case .send(let turn):
                multipeer.send(.turn(turn))
            case .peerCommitted:
                log.append(.prompt(formatter.chooseMove()))
            case .play(let events):
                await playRound(events)
            case .ended(let w):
                winner = BattleEventPlayer.shownWinner(w)
            }
        }
    }

    func playRound(_ events: [Event]) async {
        isResolvingTurn = true
        removePromptLines()
        await eventPlayer.play(events, into: self)
        // The host re-syncs with its engine, so bookkeeping the reducer
        // doesn't mirror can't drift from the display.
        if let hostState = battle?.hostState {
            state = hostState
        }
        isResolvingTurn = false
    }
}

// MARK: - Rendering
private extension MultiplayerBattleViewModel {
    func playEntrance() async {
        await eventPlayer.playEntrance(into: self, announcement: formatter.opponentReady)
    }

    func removePromptLines() {
        withAnimation(DesignKit.Animation.Primitive.easeOut25) {
            log.removeAll { $0.kind == .prompt }
        }
    }
}

extension MultiplayerBattleViewModel: BattleEventSink {}
