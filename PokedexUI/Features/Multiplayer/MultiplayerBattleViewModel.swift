import SwiftUI
import PokeBattleKit

/// `BattleViewModelProtocol` implementation that runs a turn-based battle
/// across two devices over `MultipeerService`. Host runs the engine and
/// broadcasts resolved events; guest renders received events with sides
/// flipped so its own pokemon always appears as `.player`.
///
/// Turn protocol (commit, collect, resolve):
/// 1. Each side commits a move with `.moveCommitted(turnNumber:)`.
/// 2. The host waits until it holds both its own and the peer's move for
///    the same turn, then resolves the round with its `BattleEngine`.
/// 3. The host broadcasts `.roundResolved(events:turnNumber:)` and both
///    sides play the identical event list, so damage rolls and crits can't
///    diverge between devices.
/// Turn numbers let each side ignore stale or out-of-order messages.
@MainActor
@Observable
final class MultiplayerBattleViewModel {
    private let role: MultipeerRole
    private let multipeer: any MultipeerServicing
    private let audioPlayer: AudioPlaying
    private let formatter: BattleLogFormatter
    private let spriteColors: SpriteColorResolver
    private let selfSummary: PokemonSummary
    private let peerSummary: PokemonSummary
    private let selfMoves: [Move]
    private let peerMoves: [Move]
    private(set) var typeChart: TypeChart?
    private let catalog: BattleCatalog
    /// Host only; the guest never resolves rounds locally.
    private var engine: BattleEngine?
    /// Incremented on each local commit; both peers stay in lockstep.
    private var turnNumber: Int = 0
    private var pendingSelfMove: Move?
    private var pendingPeerMoveName: String?
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
        role: MultipeerRole,
        selfSummary: PokemonSummary,
        selfMoves: [Move],
        peerSummary: PokemonSummary,
        peerMoves: [Move],
        multipeer: any MultipeerServicing,
        services: BattleServices
    ) {
        self.role = role
        self.multipeer = multipeer
        self.audioPlayer = services.audioPlayer
        self.catalog = services.catalog
        self.selfSummary = selfSummary
        self.peerSummary = peerSummary
        self.selfMoves = selfMoves
        self.peerMoves = peerMoves
        self.displayMoves = selfMoves
        self.playerName = selfSummary.name
        self.opponentName = peerSummary.name
        self.animator = BattleAnimator()
        self.formatter = BattleLogFormatter(
            playerName: selfSummary.name,
            opponentName: peerSummary.name
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
        self.state = BattleState(player: selfCombatant, opponent: peerCombatant)
        // Both peers use the chart for effectiveness labels; only the host
        // runs the engine.
        if let chart = catalog.typeChart {
            self.typeChart = chart
            if role == .host {
                self.engine = BattleEngine(state: state!, typeChart: chart)
            }
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
        state != nil && pendingSelfMove == nil && winner == nil && !isResolvingTurn
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
        guard canSelectMove else { return }

        animator.attackTick += 1
        pendingSelfMove = move
        turnNumber += 1
        log.append(.prompt(formatter.waitingForOpponent()))
        multipeer.send(.moveCommitted(moveName: move.name, turnNumber: turnNumber))
        if role == .host { await tryResolveHostTurn() }
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

    func handle(_ message: BattleMessage) async {
        switch message {
        case .moveCommitted(let moveName, let turn):
            await receivePeerMove(name: moveName, turn: turn)
        case .roundResolved(let events, let turn):
            await receiveResolution(events: events, turn: turn)
        case .battleEnded(let w):
            // The host's `Side` is from its own perspective; flip for the guest.
            self.winner = role == .host ? w : w?.opposite
        case .disconnect:
            errorMessage = Localized("multiplayer.error.disconnected")
            winner = nil
        case .hello, .challengeProposed, .challengeAccepted, .challengeDeclined, .rematch:
            break
        }
    }

    func receivePeerMove(name: String, turn: Int) async {
        if pendingSelfMove == nil {
            log.append(.prompt(formatter.chooseMove()))
        }
        // Host accepts the peer's move for the current turn, or for the next
        // turn when the peer committed first (host hasn't bumped `turnNumber`
        // yet). The guest only shows the prompt and waits for the resolution.
        guard role == .host,
              turn == turnNumber || turn == turnNumber + (pendingSelfMove == nil ? 1 : 0)
        else { return }

        pendingPeerMoveName = name
        await tryResolveHostTurn()
    }

    func receiveResolution(events: [Event], turn: Int) async {
        guard role == .guest, turn == turnNumber else { return }

        isResolvingTurn = true
        removePromptLines()
        let flipped = events.map(flip)
        await play(events: flipped)
        pendingSelfMove = nil
        isResolvingTurn = false
    }

    /// Resolves only once both moves for the turn are in; called after
    /// either side's commit arrives, whichever comes last does the work.
    func tryResolveHostTurn() async {
        guard role == .host,
              let selfMove = pendingSelfMove,
              let peerName = pendingPeerMoveName,
              let peerMove = peerMoves.first(where: { $0.name == peerName }) ?? catalog.move(named: peerName),
              var eng = engine
        else { return }
        isResolvingTurn = true
        removePromptLines()
        let events = eng.resolveRound(playerMove: selfMove, opponentMove: peerMove)
        self.engine = eng
        // Send before animating so both devices play the turn together.
        multipeer.send(.roundResolved(events: events, turnNumber: turnNumber))
        await play(events: events)
        pendingSelfMove = nil
        pendingPeerMoveName = nil
        state = eng.state
        isResolvingTurn = false
    }
}

// MARK: - Rendering
private extension MultiplayerBattleViewModel {
    func play(events: [Event]) async {
        for event in events {
            let line = formatter.format(
                event,
                playerColor: animator.playerCues.color,
                opponentColor: animator.opponentCues.color
            )
            log.append(.regular(line))
            apply(event)
            await animator.play(event)
            try? await Task.sleep(for: .milliseconds(650))
            if case .ended(let w) = event {
                winner = w ?? .player
                await playWinnerCry()
                if role == .host {
                    multipeer.send(.battleEnded(winner: w))
                }
                break
            }
        }
    }

    func apply(_ event: Event) {
        guard var snapshot = state else { return }
        BattleStateReducer.apply(event, to: &snapshot, animator: animator)
        state = snapshot
    }

    func playEntrance() async {
        await animator.playEntrance()
        log.append(.regular(formatter.opponentReady(opponentColor: animator.opponentCues.color)))
        if let cry = peerSummary.cryURL {
            await audioPlayer.play(from: cry)
        }
    }

    func playWinnerCry() async {
        guard let winner else { return }
        let cry = winner == .player ? selfSummary.cryURL : peerSummary.cryURL
        guard let cry else { return }
        try? await Task.sleep(for: .milliseconds(350))
        await audioPlayer.play(from: cry)
    }

    func removePromptLines() {
        withAnimation(DesignKit.Animation.Primitive.easeOut25) {
            log.removeAll { $0.kind == .prompt }
        }
    }

    /// Mirrors an event from the host's perspective to the guest's.
    func flip(_ event: Event) -> Event {
        switch event {
        case .used(let s, let m): .used(s.opposite, moveName: m)
        case .missed(let s): .missed(s.opposite)
        case .damaged(let s, let a, let e, let c): .damaged(s.opposite, amount: a, effectiveness: e, crit: c)
        case .statusApplied(let s, let st): .statusApplied(s.opposite, st)
        case .statusTick(let s, let st, let a): .statusTick(s.opposite, st, amount: a)
        case .statChanged(let s, let st, let d): .statChanged(s.opposite, stat: st, delta: d)
        case .healed(let s, let a): .healed(s.opposite, amount: a)
        case .recoil(let s, let a): .recoil(s.opposite, amount: a)
        case .recharging(let s): .recharging(s.opposite)
        case .wokeUp(let s): .wokeUp(s.opposite)
        case .fastAsleep(let s): .fastAsleep(s.opposite)
        case .frozenSolid(let s): .frozenSolid(s.opposite)
        case .thawed(let s): .thawed(s.opposite)
        case .fullyParalyzed(let s): .fullyParalyzed(s.opposite)
        case .lostFocus(let s): .lostFocus(s.opposite)
        case .flinched(let s): .flinched(s.opposite)
        case .failed(let s): .failed(s.opposite)
        case .hitCount(let s, let n): .hitCount(s.opposite, count: n)
        case .fainted(let s): .fainted(s.opposite)
        case .ended(let w): .ended(winner: w?.opposite)
        }
    }
}
