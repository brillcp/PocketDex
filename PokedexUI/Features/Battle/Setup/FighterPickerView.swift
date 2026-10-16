import SwiftUI
import SwiftData

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
/// level from the simulated strength ratings), and "Smart pick" chooses a
/// fair fighter; both live in `FighterPickerViewModel`. This view owns the
/// queries and hands their rows to it.
struct FighterPickerView: View {
    let onStart: (BattleLaunch) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: FighterPickerViewModel
    @Query private var allPokemon: [Pokemon]
    @Query private var team: [Pokemon]

    init(viewModel: FighterPickerViewModel, onStart: @escaping (BattleLaunch) -> Void) {
        self.viewModel = viewModel
        self.onStart = onStart
        // The opponent is excluded from both, so no path picks a mirror match.
        let opponentId = viewModel.opponent.id
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
            PokemonPickerGrid(sections: viewModel.sections, badge: matchupChip, onSelect: { viewModel.fighter = $0 })
                .opacity(viewModel.isAIThinking ? Opacity.disabled : 1)
                .safeAreaBar(edge: .bottom) { pickerButton }
                .disabled(viewModel.isAIThinking)
                .animation(DesignKit.Animation.Primitive.easeInOut20, value: viewModel.isAIThinking)
                .foregroundStyle(.white)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: dismiss.callAsFunction)
                    }
                }
                .applyPokedexStyling(title: "fighterPicker.title", navColor: .darkGrey)
                // Rebuild the sections only when either query's rows change.
                .onChange(of: RowsKey(all: allPokemon, team: team), initial: true) {
                    viewModel.update(all: allPokemon, team: team)
                }
                .task(id: allPokemon.count) {
                    await viewModel.prebuildCandidates()
                }
                .onDisappear(perform: viewModel.cancelSmartPick)
                .navigationDestination(item: $viewModel.fighter) { fighter in
                    BattleLoadoutView(viewModel: viewModel.setupViewModel(for: fighter)) { launch in
                        dismiss()
                        onStart(launch)
                    }
                }
        }
    }
}

// MARK: - Private
private extension FighterPickerView {
    /// Changes when either query's rows change.
    struct RowsKey: Equatable {
        let all: [Int]
        let team: [Int]

        init(all: [Pokemon], team: [Pokemon]) {
            self.all = all.map(\.id)
            self.team = team.map(\.id)
        }
    }

    func matchupChip(for pokemon: Pokemon) -> Chip? {
        switch viewModel.matchups[pokemon.id] {
        case .strong: Chip("matchup.strong", style: .success)
        case .even: Chip("matchup.even")
        case .weak: Chip("matchup.weak", style: .danger)
        case nil: nil
        }
    }

    var pickerButton: some View {
        PrimaryCapsuleButton(
            icon: "sparkles.2",
            title: "fighterPicker.smartPick",
            isEnabled: !viewModel.isAIThinking,
            isLoading: viewModel.isAIThinking,
            action: viewModel.pickSmart
        )
        .padding(.horizontal, DesignKit.Spacing.Primitive.s32)
        .padding(.bottom, DesignKit.Spacing.Primitive.s8)
    }
}
