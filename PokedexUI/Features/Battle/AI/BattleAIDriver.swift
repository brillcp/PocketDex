import PokeBattleKit

/// Per-battle wrapper around `BattleAIServiceProtocol` that tracks the
/// opponent's recent picks (for recency penalty) and which player moves
/// have been observed (so the AI only reasons about scouted threats).
///
/// One driver per battle, owned by `BattleViewModel` on the main actor, so
/// this per-battle memory needs no locking. The shared `BattleAIService`
/// actor does the actual picking (it only remembers recent fighter
/// suggestions across battles).
@MainActor
final class BattleAIDriver {
    private let service: BattleAIServiceProtocol
    private let historyLimit: Int
    /// The difficulty this battle is played at, fixed when it starts.
    private let difficulty: Difficulty
    private var history: [String] = []
    private var turnNumber: Int = 0
    private(set) var playerSeenMoves: Set<String> = []

    init(service: BattleAIServiceProtocol, difficulty: Difficulty, historyLimit: Int = 4) {
        self.service = service
        self.difficulty = difficulty
        self.historyLimit = historyLimit
    }

    /// Ask the service for the AI's next move. Updates the rolling
    /// recent-moves window on its way out.
    func nextOpponentMove(
        attacker: Combatant,
        defender: Combatant,
        opponentMoves: [Move],
        playerMoves: [Move],
        typeChart: TypeChart
    ) async -> Move {
        turnNumber += 1
        let pick = await service.chooseMove(
            attacker:          attacker,
            defender:          defender,
            moves:             opponentMoves,
            defenderMoves:     playerMoves,
            defenderSeenMoves: Array(playerSeenMoves),
            typeChart:         typeChart,
            recentMoves:       history,
            turnNumber:        turnNumber,
            difficulty:        difficulty
        )
        history.append(pick.name)
        if history.count > historyLimit { history.removeFirst() }
        return pick
    }

    /// Add `name` to the seen set if `events` show the player actually
    /// used a move this turn (i.e. wasn't fully paralyzed or asleep).
    func recordPlayerUsed(_ name: String, in events: [Event]) {
        let acted = events.contains { event in
            if case .used(.player, _) = event { return true }
            return false
        }
        if acted { playerSeenMoves.insert(name) }
    }
}
