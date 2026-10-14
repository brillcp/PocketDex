import PokeBattleKit
import FoundationModels

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

/// On-device AI for battle decisions with deterministic fallbacks. The
/// concrete `BattleAIService` uses an LLM where available and falls back
/// to heuristics otherwise.
protocol BattleAIServiceProtocol: Sendable {
    /// Pick the best move for this turn. `defenderSeenMoves` is the subset
    /// of the defender's moves already used in the current battle.
    func chooseMove(
        attacker: Combatant,
        defender: Combatant,
        moves: [Move],
        defenderMoves: [Move],
        defenderSeenMoves: [String],
        typeChart: TypeChart,
        recentMoves: [String],
        turnNumber: Int
    ) async -> Move
    /// Pick an opponent id from the curated candidate pool.
    func chooseOpponent(
        player: Candidate,
        candidates: [Candidate],
        typeChart: TypeChart?
    ) async -> Int?
    /// Pick a 4-move loadout, informed by what the player chose.
    func chooseLoadout(
        for fighter: Combatant,
        against opponent: Combatant,
        moves: [Move],
        playerMoves: [Move],
        typeChart: TypeChart
    ) async -> [Move]
}

/// Thin facade composing a `LanguageModelClient` with per-decision
/// strategy + prompt helpers. Each public method follows the same shape:
/// 1. Strategy produces a deterministic fallback.
/// 2. Structured generation attempts a smarter pick.
/// 3. Strategy.adjust runs post-pick corrections against either branch.
///
/// The fallback always exists before the model is asked, so a decision is
/// returned on devices without Apple Intelligence, when the model errors,
/// or when it names something that isn't on the list. Being an actor keeps
/// prompt building and inference off the main actor; it holds no
/// per-battle state (that lives in `BattleAIDriver`), so one instance is
/// shared app-wide through `AppContainer`.
actor BattleAIService {
    private let client = LanguageModelClient()
    init() {}
}

extension BattleAIService: BattleAIServiceProtocol {

    func chooseMove(
        attacker: Combatant,
        defender: Combatant,
        moves: [Move],
        defenderMoves: [Move],
        defenderSeenMoves: [String],
        typeChart: TypeChart,
        recentMoves: [String],
        turnNumber: Int
    ) async -> Move {
        aiLog("--- MOVE PICK (turn \(turnNumber)) ---")
        aiLog("\(attacker.name) \(hpPct(attacker))% vs \(defender.name) \(hpPct(defender))%")
        aiLog("Loadout: \(moves.map(\.name).joined(separator: ", "))")
        aiLog("Recent: \(recentMoves.joined(separator: ", "))")
        guard let first = moves.first else { return PokeBattleKit.move(named: "tackle")! }
        let fallback = MoveStrategy.heuristicPick(
            attacker: attacker, defender: defender, moves: moves, typeChart: typeChart, recentMoves: recentMoves
        ) ?? first
        aiLog("Heuristic fallback: \(fallback.name)")

        let movesByName = Dictionary(moves.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })

        // Only moves the player has actually used are revealed, so the AI
        // plays with the same information a human opponent would have.
        let seen = defenderSeenMoves.isEmpty ? "" : "\nDefender used: \(defenderSeenMoves.joined(separator: ", "))"
        let moveData = moves.map { m in
            let mult = typeChart.multiplier(attacking: m.typeName, defenders: defender.typeNames)
            let dmg = DamageCalculator.estimateDamage(move: m, attacker: attacker, defender: defender, typeChart: typeChart)
            let ko = dmg >= defender.currentHP
            let score = MoveScoring.inBattleScore(move: m, attacker: attacker, defender: defender, typeChart: typeChart, recentMoves: recentMoves)
            return "\(m.name) (\(m.typeName)) | \(mult)x type | \(dmg) dmg\(ko ? " KO" : "") | score \(String(format: "%.1f", score))"
        }.joined(separator: "\n")
        let prompt = """
        \(BattleContext.compact(attacker: attacker, defender: defender, turnNumber: turnNumber))\(seen)

        Available moves (type multiplier, estimated output, heuristic score):
        \(moveData)

        \(BattleContext.tacticalHint(attacker: attacker, defender: defender, moves: moves))
        """

        let pick = await client.decide(
            fallback: fallback,
            prompt: prompt,
            generating: MovePickResult.self,
            temperature: 0.35,
            instructions: .move,
            resolve: { result in
                aiLog("LLM chose: \(result.moveName)")
                return movesByName[result.moveName]
            },
            adjust: {
                let adjusted = MoveStrategy.adjust(
                    pick: $0, attacker: attacker, defender: defender,
                    moves: moves, typeChart: typeChart, fallback: fallback
                )
                if adjusted.name != $0.name { aiLog("Adjust: \($0.name) -> \(adjusted.name)") }
                return adjusted
            }
        )
        aiLog("FINAL PICK: \(pick.name)")
        return pick
    }

    func chooseOpponent(
        player: Candidate,
        candidates: [Candidate],
        typeChart: TypeChart?
    ) async -> Int? {
        let pool = candidates.filter { $0.id != player.id }
        guard !pool.isEmpty else { return nil }
        aiLog("--- OPPONENT PICK ---")
        aiLog("Player: \(player.name) (\(player.typeNames.joined(separator: "/")), BST \(player.baseStatTotal))")
        aiLog("Pool size: \(pool.count)")
        let fallback = OpponentStrategy.heuristicPick(player: player, candidates: pool, typeChart: typeChart)
        if let fbId = fallback, let fb = pool.first(where: { $0.id == fbId }) {
            aiLog("Heuristic fallback: \(fb.name) (BST \(fb.baseStatTotal))")
        }
        let output = OpponentPrompt.build(player: player, candidates: pool, typeChart: typeChart)

        let pick = await client.decide(
            fallback: fallback,
            prompt: output.prompt,
            generating: OpponentPickResult.self,
            temperature: 0.3,
            instructions: .opponent,
            resolve: { OpponentPrompt.parsePick(raw: String($0.index), indexMap: output.indexMap) },
            adjust: { $0 }
        )
        if let id = pick, let chosen = pool.first(where: { $0.id == id }) {
            aiLog("FINAL OPPONENT: \(chosen.name) (\(chosen.typeNames.joined(separator: "/")), BST \(chosen.baseStatTotal))")
        }
        return pick
    }

    func chooseLoadout(
        for fighter: Combatant,
        against opponent: Combatant,
        moves: [Move],
        playerMoves: [Move],
        typeChart: TypeChart
    ) async -> [Move] {
        aiLog("--- LOADOUT PICK ---")
        aiLog("\(fighter.name) (\(fighter.typeNames.joined(separator: "/"))) vs \(opponent.name) (\(opponent.typeNames.joined(separator: "/")))")
        aiLog("Move pool: \(moves.count) moves")
        aiLog("Player chose: \(playerMoves.map(\.name).joined(separator: ", "))")
        guard moves.count > 4 else { return moves }
        let fallback = LoadoutStrategy.heuristicPick(
            fighter: fighter, opponent: opponent, moves: moves, typeChart: typeChart
        )
        aiLog("Heuristic fallback: \(fallback.map(\.name).joined(separator: ", "))")
        // Prompt with a pre-ranked shortlist rather than the full learnset:
        // smaller prompt, and fewer weak options for the model to pick.
        let shortlist = LoadoutStrategy.shortlist(
            fighter: fighter, opponent: opponent, moves: moves, typeChart: typeChart
        )
        aiLog("Shortlist: \(shortlist.count) moves")

        let movesByName = Dictionary(shortlist.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })

        let moveData = shortlist.map { m in
            let mult = typeChart.multiplier(attacking: m.typeName, defenders: opponent.typeNames)
            let dmg = DamageCalculator.estimateDamage(move: m, attacker: fighter, defender: opponent, typeChart: typeChart)
            return "\(m.name) (\(m.typeName)) | \(mult)x type | \(dmg) dmg"
        }.joined(separator: "\n")
        let prompt = """
        Pick 4 moves for \(fighter.name) (\(fighter.typeNames.joined(separator: "/"))) vs \(opponent.name) (\(opponent.typeNames.joined(separator: "/"))).

        Available moves (type multiplier, estimated output):
        \(moveData)

        Select a balanced set: powerful moves with good type coverage, plus utility (status, boosts).
        """

        let picks = await client.decide(
            fallback: fallback,
            prompt: prompt,
            generating: LoadoutPickResult.self,
            temperature: 0.4,
            instructions: .loadout,
            resolve: { result in
                let parsed = result.moveNames.compactMap { movesByName[$0] }
                aiLog("LLM parsed: \(parsed.map(\.name).joined(separator: ", "))")
                guard !parsed.isEmpty else { return nil }
                let filled = LoadoutStrategy.fill(
                    seed: parsed, fighter: fighter, opponent: opponent,
                    moves: shortlist, typeChart: typeChart, count: 4
                )
                if filled.count > parsed.count {
                    aiLog("Filled to 4: \(filled.map(\.name).joined(separator: ", "))")
                }
                return filled
            },
            adjust: {
                let adjusted = LoadoutStrategy.adjust(
                    picks: $0, pool: moves, fighter: fighter, opponent: opponent, typeChart: typeChart
                )
                if adjusted.map(\.name) != $0.map(\.name) {
                    aiLog("Adjust: \($0.map(\.name).joined(separator: ", ")) -> \(adjusted.map(\.name).joined(separator: ", "))")
                }
                return adjusted
            }
        )
        aiLog("FINAL LOADOUT: \(picks.map(\.name).joined(separator: ", "))")
        return picks
    }
}

// MARK: - Move + Prompt

private extension Move {
    /// Compact one-liner for LLM prompts: `"thunderbolt (electric) 90/100"`.
    var promptDescription: String {
        let pwr = power.map(String.init) ?? "-"
        let acc = accuracy.map(String.init) ?? "-"
        return "\(name) (\(typeName)) \(pwr)/\(acc)"
    }
}
