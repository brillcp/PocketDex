import SwiftUI
import SwiftData
import PokeBattleKit

/// Sheet for choosing your fighter against a challenged Pokémon.
///
/// "Battle" on a Pokémon's page means "I want to battle this one", so the
/// opponent is fixed and the player picks who to send out, as in the games.
/// User-facing copy says "player", "opponent" or "My team", never
/// "Pokémon":
/// - **My team**: team (bookmarked) Pokémon.
/// - **Gen I, Gen II, ...**: everyone by generation, so the player is never
///   blocked.
///
/// Every cell is tagged with how the matchup looks (predicted at equal
/// level from the simulated strength ratings).
///
/// "Smart pick" chooses a fair fighter from everyone, team members included. The opponent is excluded from both
/// sections and the candidates, so no path can pick a mirror match.
struct FighterPickerView: View {
    let opponent: Pokemon
    let opponentTypes: [String]
    let onStart: (BattleLaunch) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @Query private var allPokemon: [Pokemon]
    @Query private var team: [Pokemon]
    @State private var isAIThinking = false
    @State private var fighter: Pokemon?
    @State private var candidateCache: [Candidate]?
    /// Built when the team or the Pokédex changes, not on every render.
    @State private var sections: [PokemonGridSection] = []
    /// Each candidate's matchup against the opponent, by id, built once the
    /// candidates are; cells read it instead of rating themselves.
    @State private var matchups: [Int: Matchup] = [:]
    @State private var smartPickTask: Task<Void, Never>?

    init(
        opponent: Pokemon,
        opponentTypes: [String] = [],
        onStart: @escaping (BattleLaunch) -> Void
    ) {
        self.opponent = opponent
        self.opponentTypes = opponentTypes
        self.onStart = onStart
        let opponentId = opponent.id
        _allPokemon = Query(
            filter: #Predicate<Pokemon> { $0.id != opponentId },
            sort: \.id
        )
        _team = Query(
            filter: #Predicate<Pokemon> { $0.isBookmarked && $0.id != opponentId },
            sort: \.id
        )
    }

    var body: some View {
        NavigationStack {
            PokemonPickerGrid(sections: sections, badge: matchupChip, onSelect: { fighter = $0 })
                .opacity(isAIThinking ? Opacity.disabled : 1)
                .safeAreaBar(edge: .bottom) { pickerButton }
                .disabled(isAIThinking)
                .animation(DesignKit.Animation.Primitive.easeInOut20, value: isAIThinking)
                .foregroundStyle(.white)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: dismiss.callAsFunction)
                    }
                }
                .applyPokedexStyling(title: "Choose player", navColor: .darkGrey)
                .onChange(of: SectionsKey(all: allPokemon, team: team), initial: true) {
                    sections = buildSections()
                }
                .task(id: allPokemon.count) {
                    await prebuildCandidatesIfNeeded()
                }
                // A pick finishing after the sheet closes mustn't push.
                .onDisappear { smartPickTask?.cancel() }
                .navigationDestination(item: $fighter) { fighter in
                    BattleLoadoutView(
                        viewModel: BattleSetupViewModel(
                            player: fighter,
                            opponent: opponent,
                            aiService: container.battleAI,
                            rules: container.battleRules
                        ), onStart: { launch in
                            dismiss()
                            onStart(launch)
                        }
                    )
                }
        }
    }
}

// MARK: - Private
private extension FighterPickerView {
    /// How a candidate is predicted to do against the opponent.
    enum Matchup {
        case strong, even, weak
    }

    /// Changes when either query's rows change, so the sections are rebuilt
    /// only then.
    struct SectionsKey: Equatable {
        let all: [Int]
        let team: [Int]

        init(all: [Pokemon], team: [Pokemon]) {
            self.all = all.map(\.id)
            self.team = team.map(\.id)
        }
    }

    func buildSections() -> [PokemonGridSection] {
        let teamSection = team.isEmpty ? [] : [
            PokemonGridSection(id: "team", title: MyTeam.title, pokemon: team, showsBadges: true)
        ]
        return teamSection + generationSections
    }

    /// Everyone grouped by generation ("Gen I", "Gen II", ...), in Pokédex
    /// order within each. Forms count as their species' generation; any
    /// without one go last, untitled.
    var generationSections: [PokemonGridSection] {
        let byGeneration = Dictionary(grouping: allPokemon) { $0.generationName.flatMap(Self.generationNumber) }
        return byGeneration
            .sorted { ($0.key ?? .max) < ($1.key ?? .max) }
            .map { number, pokemon in
                PokemonGridSection(
                    id: number.map { "gen-\($0)" } ?? "gen-other",
                    title: number.map { "Gen \(Self.romanNumeral($0))" },
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

    var opponentCandidate: Candidate {
        Candidate(pokemon: opponent, fallbackTypes: opponentTypes)
    }

    func matchupChip(for pokemon: Pokemon) -> Chip? {
        switch matchups[pokemon.id] {
        case .strong: Chip("Strong", style: .success)
        case .even: Chip("Even")
        case .weak: Chip("Weak", style: .danger)
        case nil: nil
        }
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

    var pickerButton: some View {
        PrimaryCapsuleButton(
            icon: "sparkles.2",
            title: "Smart pick",
            isEnabled: !isAIThinking,
            isLoading: isAIThinking,
            action: pickSmart
        )
        .padding(.horizontal, DesignKit.Spacing.Primitive.s32)
        .padding(.bottom, DesignKit.Spacing.Primitive.s8)
    }

    func pickSmart() {
        guard !allPokemon.isEmpty, !isAIThinking else { return }
        isAIThinking = true

        let target = opponentCandidate
        let chart = PokeBattleKit.loadedTypeChart
        let aiService = container.battleAI

        smartPickTask = Task {
            // Everyone (team members included): a big pool always has fair
            // matchups to vary between. The AI service picks among them,
            // skipping recent suggestions, off the main actor (it's an actor).
            let candidates = await ensureCandidates()
            let pickedId = await aiService.chooseFighter(
                against: target,
                candidates: candidates,
                typeChart: chart
            )
            isAIThinking = false
            guard !Task.isCancelled else { return }
            // Map the id back to a main-context model; fall back to a random
            // candidate if the AI returned nothing usable.
            if let pickedId, let match = allPokemon.first(where: { $0.id == pickedId }) {
                fighter = match
            } else if let id = candidates.randomElement()?.id,
                      let match = allPokemon.first(where: { $0.id == id }) {
                fighter = match
            }
        }
    }

    /// Builds the candidate cache on view appear so a "Smart pick" tap can
    /// jump straight to scoring. The SwiftData traversal runs on the
    /// background store, off the main actor.
    func prebuildCandidatesIfNeeded() async {
        guard candidateCache == nil, !allPokemon.isEmpty else { return }
        let built = await fighterCandidates()
        candidateCache = built
        matchups = buildMatchups(built)
    }

    /// Returns the cached candidates, building them if the prebuild
    /// hasn't completed yet (fallback for an eager "Smart pick" tap).
    func ensureCandidates() async -> [Candidate] {
        if let cached = candidateCache { return cached }
        let built = await fighterCandidates()
        candidateCache = built
        matchups = buildMatchups(built)
        return built
    }

    /// Every stored pokemon except the opponent, matching `allPokemon`'s
    /// query, so the AI and random fallback can never pick a mirror match.
    func fighterCandidates() async -> [Candidate] {
        let opponentId = opponent.id
        return await container.repository.battleCandidates().filter { $0.id != opponentId }
    }
}
