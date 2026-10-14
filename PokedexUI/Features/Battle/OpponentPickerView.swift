import SwiftUI
import SwiftData
import PokeBattleKit

/// Sheet for choosing a battle opponent from the full pokedex.
///
/// Opponents can be tapped directly or chosen with "Smart pick": the pool is
/// narrowed to a balanced set by a deterministic score, then
/// `BattleAIService` (on-device model, with a deterministic fallback) picks
/// one from it. The player is excluded both from the `@Query` and from the
/// candidate snapshots, so neither path can pick a mirror match.
struct OpponentPickerView: View {
    let player: Pokemon
    let playerTypes: [String]
    let onStart: (BattleLaunch) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @Query private var allPokemon: [Pokemon]
    @State private var isAIThinking = false
    @State private var setupOpponent: Pokemon?
    @State private var candidateCache: [Candidate]?

    init(
        player: Pokemon,
        playerTypes: [String] = [],
        onStart: @escaping (BattleLaunch) -> Void
    ) {
        self.player = player
        self.playerTypes = playerTypes
        self.onStart = onStart
        let playerId = player.id
        _allPokemon = Query(
            filter: #Predicate<Pokemon> { $0.id != playerId },
            sort: \.id
        )
    }

    var body: some View {
        NavigationStack {
            PokemonPickerGrid(pokemon: allPokemon, onSelect: { setupOpponent = $0 })
                .opacity(isAIThinking ? Opacity.disabled : 1)
                .safeAreaBar(edge: .bottom) { pickerButton }
                .disabled(isAIThinking)
                .animation(.easeInOut(duration: 0.2), value: isAIThinking)
                .foregroundStyle(.white)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: dismiss.callAsFunction)
                    }
                }
                .applyPokedexStyling(title: "Pick opponent", navColor: .darkGrey)
                .task(id: allPokemon.count) {
                    await prebuildCandidatesIfNeeded()
                }
                .navigationDestination(item: $setupOpponent) { opp in
                    BattleSetupView(
                        viewModel: BattleSetupViewModel(
                            player: player,
                            opponent: opp,
                            aiService: container.battleAI
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
private extension OpponentPickerView {
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

        let playerCandidate = Candidate(pokemon: player, fallbackTypes: playerTypes)
        let chart: TypeChart? = PokeBattleKit.isInitialized ? PokeBattleKit.typeChart : nil
        let aiService = container.battleAI

        Task {
            let candidates = await ensureCandidates()

            let pool = await Self.balancedPool(from: candidates, player: playerCandidate, chart: chart)

            let pickedId = await aiService.chooseOpponent(
                player: playerCandidate,
                candidates: pool,
                typeChart: chart
            )
            isAIThinking = false
            // Map the id back to a main-context model; fall back to a random
            // pool member if the AI returned nothing usable.
            if let pickedId, let match = allPokemon.first(where: { $0.id == pickedId }) {
                setupOpponent = match
            } else if let id = pool.randomElement()?.id,
                      let match = allPokemon.first(where: { $0.id == id }) {
                setupOpponent = match
            }
        }
    }

    /// Scores the whole candidate pool on the cooperative pool, off the
    /// main actor. `@concurrent` makes the hop explicit: with the module's
    /// `nonisolated` default and Approachable Concurrency, a plain async
    /// function would run on the caller's actor (main) instead.
    @concurrent
    static func balancedPool(from candidates: [Candidate], player: Candidate, chart: TypeChart?) async -> [Candidate] {
        OpponentStrategy.balancedPool(
            from: candidates,
            playerBST: player.baseStatTotal,
            playerTypes: player.typeNames,
            chart: chart
        )
    }

    /// Builds the candidate cache on view appear so a "Smart pick" tap can
    /// jump straight to scoring. The SwiftData traversal runs on the
    /// background store, off the main actor.
    func prebuildCandidatesIfNeeded() async {
        guard candidateCache == nil, !allPokemon.isEmpty else { return }
        candidateCache = await opponentCandidates()
    }

    /// Returns the cached candidates, building them if the prebuild
    /// hasn't completed yet (fallback for an eager "Smart pick" tap).
    func ensureCandidates() async -> [Candidate] {
        if let cached = candidateCache { return cached }
        let built = await opponentCandidates()
        candidateCache = built
        return built
    }

    /// Every stored pokemon except the player, matching `allPokemon`'s
    /// query, so the AI and random fallback can never pick the player.
    func opponentCandidates() async -> [Candidate] {
        let playerId = player.id
        return await container.repository.opponentCandidates().filter { $0.id != playerId }
    }
}
