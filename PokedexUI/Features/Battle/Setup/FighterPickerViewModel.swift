import Foundation
import PokeBattleKit

/// Drives `FighterPickerView`: the picker's sections, each candidate's
/// matchup against the opponent, and "Smart pick".
///
/// The view owns the `@Query`s (SwiftData pushes store changes to views) and
/// hands each new result to `update(all:team:)`, so the sections and the
/// smart pick work from the same rows. Candidate snapshots are built once,
/// off the main actor, and reused for both the matchup tags and Smart pick.
@MainActor
@Observable
final class FighterPickerViewModel {
    /// How a candidate is predicted to do against the opponent.
    enum Matchup {
        case strong, even, weak
    }

    let opponent: Pokemon
    private let opponentTypes: [String]
    private let repository: any PokedexSnapshotReading
    private let aiService: any FighterChoosing
    private let catalog: any BattleCatalogReading
    private let makeSetup: @MainActor (Pokemon) -> BattleSetupViewModel

    private var allPokemon: [Pokemon] = []
    private var candidateCache: [Candidate]?
    private var smartPickTask: Task<Void, Never>?

    /// Built when the team or the Pokédex changes, not on every render.
    private(set) var sections: [PokemonGridSection] = []
    /// Each candidate's matchup by id; cells read it instead of rating
    /// themselves.
    private(set) var matchups: [Int: Matchup] = [:]
    private(set) var isAIThinking = false
    /// The chosen fighter; drives the push to the loadout screen.
    var fighter: Pokemon?

    /// `makeSetup` builds the loadout screen's view model for a chosen
    /// fighter against `opponent` (see `ViewModelFactory`).
    init(
        opponent: Pokemon,
        opponentTypes: [String],
        repository: any PokedexSnapshotReading,
        aiService: any FighterChoosing,
        catalog: any BattleCatalogReading,
        makeSetup: @escaping @MainActor (Pokemon) -> BattleSetupViewModel
    ) {
        self.opponent = opponent
        self.opponentTypes = opponentTypes
        self.repository = repository
        self.aiService = aiService
        self.catalog = catalog
        self.makeSetup = makeSetup
    }

    /// New rows from the view's queries: everyone but the opponent, and the
    /// team members among them.
    func update(all: [Pokemon], team: [Pokemon]) {
        allPokemon = all
        let teamSection = team.isEmpty ? [] : [
            PokemonGridSection(id: "team", title: MyTeam.title, pokemon: team, showsBadges: true)
        ]
        sections = teamSection + Self.generationSections(all)
    }

    /// Builds the candidate snapshots (and the matchup tags) ahead of time,
    /// so a "Smart pick" tap can jump straight to scoring.
    func prebuildCandidates() async {
        guard candidateCache == nil, !allPokemon.isEmpty else { return }
        _ = await ensureCandidates()
    }

    /// Picks a fair fighter from everyone (team members included): a big
    /// pool always has fair matchups to vary between. The AI service picks
    /// among them, skipping recent suggestions, off the main actor.
    func pickSmart() {
        guard !allPokemon.isEmpty, !isAIThinking else { return }
        isAIThinking = true
        let target = opponentCandidate
        let chart = catalog.typeChart

        smartPickTask = Task {
            let candidates = await ensureCandidates()
            let pickedId = await aiService.chooseFighter(against: target, candidates: candidates, typeChart: chart)
            isAIThinking = false
            guard !Task.isCancelled else { return }
            // Map the id back to a main-context model; fall back to a random
            // candidate if the AI returned nothing usable.
            let id = pickedId ?? candidates.randomElement()?.id
            fighter = allPokemon.first { $0.id == id }
        }
    }

    /// A pick finishing after the sheet closes mustn't push.
    func cancelSmartPick() {
        smartPickTask?.cancel()
    }

    /// The loadout screen for `fighter` against the opponent.
    func setupViewModel(for fighter: Pokemon) -> BattleSetupViewModel {
        makeSetup(fighter)
    }
}

// MARK: - Private
private extension FighterPickerViewModel {
    var opponentCandidate: Candidate {
        Candidate(pokemon: opponent, fallbackTypes: opponentTypes)
    }

    /// The cached candidates, building them (and the matchups) on first use.
    /// The SwiftData traversal runs on the background store. The opponent
    /// is excluded, matching the view's query, so no path can pick a mirror
    /// match.
    func ensureCandidates() async -> [Candidate] {
        if let candidateCache { return candidateCache }
        let opponentId = opponent.id
        let built = await repository.battleCandidates().filter { $0.id != opponentId }
        candidateCache = built
        matchups = buildMatchups(built)
        return built
    }

    /// How each candidate is predicted to do against the opponent at equal
    /// level, using the same fair range as "Smart pick".
    func buildMatchups(_ candidates: [Candidate]) -> [Int: Matchup] {
        let target = opponentCandidate
        let fair = MatchmakingStrategy.fairWinChance
        var result: [Int: Matchup] = [:]
        for candidate in candidates {
            let chance = MatchmakingStrategy.predictedWinChance(of: candidate, against: target)
            result[candidate.id] = chance > fair.upperBound ? .strong : chance < fair.lowerBound ? .weak : .even
        }
        return result
    }

    /// Everyone grouped by generation ("Gen I", "Gen II", ...), in Pokédex
    /// order within each. Forms count as their species' generation; any
    /// without one go last, untitled.
    static func generationSections(_ pokemon: [Pokemon]) -> [PokemonGridSection] {
        let byGeneration = Dictionary(grouping: pokemon) { $0.generationName.flatMap(generationNumber) }
        return byGeneration
            .sorted { ($0.key ?? .max) < ($1.key ?? .max) }
            .map { number, pokemon in
                PokemonGridSection(
                    id: number.map { "gen-\($0)" } ?? "gen-other",
                    title: number.map { "fighterPicker.generation \(romanNumeral($0))" },
                    pokemon: pokemon,
                    showsBadges: true
                )
            }
    }

    /// 4 for PokeAPI's "generation-iv".
    static func generationNumber(_ name: String) -> Int? {
        let numeral = name.replacingOccurrences(of: "generation-", with: "").uppercased()
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10]
        var total = 0
        var previous = 0
        for character in numeral.reversed() {
            guard let value = values[character] else { return nil }
            total += value < previous ? -value : value
            previous = max(previous, value)
        }
        return total > 0 ? total : nil
    }

    static func romanNumeral(_ number: Int) -> String {
        let numerals: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var remaining = number
        var result = ""
        for (value, numeral) in numerals {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
}
