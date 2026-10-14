import PokeBattleKit

// MARK: - OpponentPrompt

/// Builds the prompt asking the LLM to pick a fair opponent from a
/// pre-filtered candidate pool, and parses the model's index reply.
enum OpponentPrompt {

    struct Output {
        let prompt: String
        let indexMap: [Int: Int]
    }

    static func build(
        player: Candidate,
        candidates: [Candidate],
        typeChart: TypeChart?
    ) -> Output {
        var indexMap: [Int: Int] = [:]
        let playerBST = player.baseStatTotal
        let roster = Array(candidates.indices).shuffled().enumerated().map { displayIdx, originalIdx in
            let idx = displayIdx + 1
            indexMap[idx] = candidates[originalIdx].id
            return describe(candidates[originalIdx], index: idx, player: player, playerBST: playerBST, typeChart: typeChart)
        }.joined(separator: "\n")

        let prompt = """
        Pick a fair opponent for \(player.name) (\(player.typeNames.joined(separator: "/")), BST \(playerBST)).

        \(roster)

        If "mutual threat", prefer it. If "stronger", avoid it. Return ONLY the number.
        """
        return Output(prompt: prompt, indexMap: indexMap)
    }

    static func parsePick(raw: String, indexMap: [Int: Int]) -> Int? {
        guard let match = raw.firstMatch(of: /\d+/),
              let displayIdx = Int(match.output) else { return nil }
        return indexMap[displayIdx]
    }
}

// MARK: - Private
private extension OpponentPrompt {

    static func describe(
        _ candidate: Candidate,
        index: Int,
        player: Candidate,
        playerBST: Int,
        typeChart: TypeChart?
    ) -> String {
        let types = candidate.typeNames.joined(separator: "/")
        let bstDelta = candidate.baseStatTotal - playerBST
        let bstNote = bstDelta > 20 ? "stronger" : bstDelta < -20 ? "weaker" : "similar"
        var line = "\(index). \(candidate.name) (\(types), BST \(candidate.baseStatTotal), \(bstNote))"

        if let chart = typeChart, !player.typeNames.isEmpty, !candidate.typeNames.isEmpty {
            line += matchupTag(chart: chart, candidate: candidate, player: player)
        }
        if candidate.isLegendary { line += " [legendary]" }
        if candidate.isMythical { line += " [mythical]" }
        return line
    }

    static func matchupTag(
        chart: TypeChart,
        candidate: Candidate,
        player: Candidate
    ) -> String {
        let cPressure = chart.bestSTABMultiplier(attackerTypes: candidate.typeNames, defenderTypes: player.typeNames)
        let pPressure = chart.bestSTABMultiplier(attackerTypes: player.typeNames, defenderTypes: candidate.typeNames)
        var matchup: [String] = []
        if cPressure >= 2 { matchup.append("SE STAB vs you") }
        else if cPressure < 1, cPressure > 0 { matchup.append("resisted vs you") }
        else if cPressure == 0 { matchup.append("immune to their STAB") }
        if pPressure >= 2 { matchup.append("you hit SE") }
        else if pPressure < 1, pPressure > 0 { matchup.append("you resisted") }
        else if pPressure == 0 { matchup.append("they immune to you") }
        if cPressure >= 1.5, pPressure >= 1.5 { matchup.append("mutual threat") }
        return matchup.isEmpty ? "" : " [\(matchup.joined(separator: ", "))]"
    }
}
