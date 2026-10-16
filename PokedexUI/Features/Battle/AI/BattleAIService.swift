import PokeBattleKit

/// Debug-only AI logging. Compiles to nothing in release builds.
@inline(__always)
func aiLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[AI] \(message())")
    #endif
}

private func hpPct(_ c: Combatant) -> Int {
    Int(Double(c.currentHP) / Double(max(1, c.maxHP)) * 100)
}

/// The AI opponent's decisions, one protocol per screen that asks: the
/// battle picks moves, the fighter picker fighters, the loadout screen
/// loadouts. Decisions take the `difficulty` to play at, so the player's
/// setting applies from the next decision on.
typealias BattleAIServiceProtocol = MoveChoosing & FighterChoosing & LoadoutChoosing

protocol MoveChoosing: Sendable {
    /// Pick the move for this turn. `defenderSeenMoves` is the subset of
    /// the defender's moves already used in the current battle; the AI only
    /// reasons about those, like a human opponent would. `nil` only when
    /// `moves` is empty and Struggle isn't loaded.
    func chooseMove(
        attacker: Combatant,
        defender: Combatant,
        moves: [Move],
        defenderMoves: [Move],
        defenderSeenMoves: [String],
        typeChart: TypeChart,
        recentMoves: [String],
        turnNumber: Int,
        difficulty: Difficulty
    ) async -> Move?
}

protocol FighterChoosing: Sendable {
    /// Pick the player's fighter id from `candidates` to challenge
    /// `opponent` with (the whole Pokédex is fine: the service picks among
    /// the fair matchups).
    func chooseFighter(
        against opponent: Candidate,
        candidates: [Candidate],
        typeChart: TypeChart?
    ) async -> Int?
}

protocol LoadoutChoosing: Sendable {
    /// Pick the AI's loadout (up to four moves) against the player's
    /// Pokémon.
    func chooseLoadout(
        for fighter: Combatant,
        against opponent: Combatant,
        moves: [Move],
        playerMoves: [Move],
        typeChart: TypeChart,
        difficulty: Difficulty
    ) async -> [Move]
}

/// The AI opponent, built entirely on PokeBattleKit's rule-based AI:
/// - **Fighters:** `MatchmakingStrategy.pick` from the opponent's side, a
///   random fair matchup by simulated battle strength (`PokemonStrength`),
///   favouring tense ones and skipping fighters suggested against this
///   opponent recently.
/// - **Loadouts:** `LoadoutStrategy`'s role-based pick (two attack types,
///   then a status, boost or heal move or more coverage), with easy mode's
///   handicap.
/// - **Moves:** `MoveStrategy`'s pick for the difficulty, then its
///   corrections.
///
/// There's no language model: every decision is deterministic per
/// difficulty (or seeded random), instant, works on every device, and is
/// exactly what PokeBattleKit's whole-Pokédex simulation tests. An actor so
/// scoring the whole Pokédex for an opponent pick stays off the main actor;
/// its only state is the recent-opponents memory, shared app-wide through
/// `AppContainer`.
actor BattleAIService {
    /// Fighters suggested against each opponent recently, newest last, so
    /// "Smart pick" doesn't keep suggesting the same one.
    private var recentFighters: [Int: [Int]] = [:]
    /// How many recent fighters to skip.
    private let recentFighterMemory: Int
    /// For Struggle, the fallback when an attacker has no moves.
    private let catalog: any BattleCatalogReading

    init(catalog: any BattleCatalogReading, recentFighterMemory: Int = 10) {
        self.catalog = catalog
        self.recentFighterMemory = recentFighterMemory
    }
}

extension BattleAIService: MoveChoosing, FighterChoosing, LoadoutChoosing {

    func chooseMove(
        attacker: Combatant,
        defender: Combatant,
        moves: [Move],
        defenderMoves: [Move],
        defenderSeenMoves: [String],
        typeChart: TypeChart,
        recentMoves: [String],
        turnNumber: Int,
        difficulty: Difficulty
    ) async -> Move? {
        guard let first = moves.first ?? catalog.move(named: "struggle") else { return nil }
        // Information parity: the AI only knows the player's moves it has
        // seen used, as a human opponent would.
        let scouted = defender.knowing(onlyMoves: defenderSeenMoves)
        let pick = MoveStrategy.heuristicPick(
            attacker: attacker, defender: scouted, moves: moves, typeChart: typeChart,
            recentMoves: recentMoves, difficulty: difficulty
        ) ?? first
        let fallback = MoveStrategy.strongestAttack(attacker: attacker, defender: scouted, moves: moves, typeChart: typeChart) ?? pick
        let final = MoveStrategy.adjust(
            pick: pick, attacker: attacker, defender: scouted,
            moves: moves, typeChart: typeChart, fallback: fallback
        )
        aiLog("Turn \(turnNumber) (\(difficulty)): \(attacker.name) \(hpPct(attacker))% vs \(defender.name) \(hpPct(defender))% -> \(final.name)\(final.name != pick.name ? " (adjusted from \(pick.name))" : "")")
        return final
    }

    func chooseFighter(
        against opponent: Candidate,
        candidates: [Candidate],
        typeChart: TypeChart?
    ) async -> Int? {
        // Fairness is symmetric (a 35-65% win chance either way, and the
        // same type checks), so the matchmaking strategy picks a fair fighter
        // when asked from the opponent's side.
        let recent = recentFighters[opponent.id, default: []]
        guard let pick = MatchmakingStrategy.pick(
            for: opponent, from: candidates, typeChart: typeChart, excluding: Set(recent)
        ) else { return nil }
        recentFighters[opponent.id] = Array((recent + [pick.id]).suffix(recentFighterMemory))
        let chance = MatchmakingStrategy.predictedWinChance(of: pick, against: opponent)
        aiLog("Fighter vs \(opponent.name) (\(Int(opponent.strength))): \(pick.name) (\(Int(pick.strength))), predicted win chance \(Int(chance * 100))%")
        return pick.id
    }

    func chooseLoadout(
        for fighter: Combatant,
        against opponent: Combatant,
        moves: [Move],
        playerMoves: [Move],
        typeChart: TypeChart,
        difficulty: Difficulty
    ) async -> [Move] {
        let picks = LoadoutStrategy.adjust(
            picks: LoadoutStrategy.heuristicPick(fighter: fighter, opponent: opponent, moves: moves, typeChart: typeChart),
            pool: moves, fighter: fighter, opponent: opponent, typeChart: typeChart, difficulty: difficulty
        )
        aiLog("Loadout for \(fighter.name) vs \(opponent.name) (\(difficulty)): \(picks.map(\.name).joined(separator: ", "))")
        return picks
    }
}
