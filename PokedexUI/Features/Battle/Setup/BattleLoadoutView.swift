import SwiftUI
import PokeBattleKit

/// Loadout screen for picking 4 moves before battle.
///
/// Flow: pick four moves, tap Start (asks the AI for the opponent's
/// loadout), and the battle launches automatically once `phase` reaches
/// `.readyToStart`. The `BattleViewModel` is built here and passed up
/// through `onStart` in a `BattleLaunch`.
struct BattleLoadoutView<ViewModel: BattleSetupViewModelProtocol>: View {
    @Environment(\.container) private var container
    @AppStorage(BattleDifficulty.key) private var difficulty = BattleDifficulty.defaultValue

    @State private var viewModel: ViewModel
    private let onStart: (BattleLaunch) -> Void

    init(viewModel: ViewModel, onStart: @escaping (BattleLaunch) -> Void) {
        self.viewModel = viewModel
        self.onStart = onStart
    }

    var body: some View {
        content
            .applyPokedexStyling(title: Localized("loadout.title"), navColor: .darkGrey)
            .foregroundStyle(.white)
            .task { await viewModel.prepare() }
            .onChange(of: viewModel.phase) { _, newPhase in
                if newPhase == .readyToStart { startBattle() }
            }
    }
}

// MARK: - Private
private extension BattleLoadoutView {
    func startBattle() {
        guard let player = viewModel.playerPokemon,
              let opponent = viewModel.opponentPokemon,
              let opponentMoves = viewModel.opponentLoadout
        else { return }
        let battleViewModel = BattleViewModel(
            player: player,
            opponent: opponent,
            playerMoves: viewModel.selection.selectedMoves,
            opponentMoves: opponentMoves,
            difficulty: difficulty,
            container: container
        )
        onStart(BattleLaunch(viewModel: battleViewModel))
    }

    var content: some View {
        Group {
            if let error = viewModel.errorMessage {
                errorState(error).transition(.opacity)
            } else if viewModel.phase == .loading {
                loadingState.transition(.opacity)
            } else {
                loadout.transition(.opacity)
            }
        }
        .animation(DesignKit.Animation.Primitive.easeInOut20, value: viewModel.phase)
        .animation(DesignKit.Animation.Primitive.easeInOut20, value: viewModel.errorMessage)
    }

    // MARK: - States

    var loadingState: some View {
        PixelSpinner(text: "battleSetup.preparing")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func errorState(_ message: String) -> some View {
        Text(message)
            .font(.pixel14)
            .padding(DesignKit.Spacing.Primitive.s16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loadout

    var loadout: some View {
        let busy = viewModel.phase == .awaitingAI
        return ScrollView {
            VStack {
                matchupRow
                typeMatchup
                movePicker
            }
        }
        .disabled(busy)
        .opacity(busy ? Opacity.disabled : 1)
        .animation(DesignKit.Animation.Primitive.easeInOut20, value: busy)
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom) { bottomBar }
        .animation(DesignKit.Animation.Primitive.snappy20, value: viewModel.selection.isFull)
    }

    var matchupRow: some View {
        HStack(alignment: .top, spacing: DesignKit.Spacing.Primitive.s2) {
            if let player = viewModel.playerPokemon {
                fighterCard(pokemon: player, summary: viewModel.playerSummary, level: container.battleRules.level)
            }
            VStack {
                Spacer()
                Chip("VS", style: .primary, size: .medium)
                Spacer()
            }
            if let opponent = viewModel.opponentPokemon {
                fighterCard(
                    pokemon: opponent,
                    summary: viewModel.opponentSummary,
                    level: container.battleRules.opponentLevel(for: difficulty)
                )
            }
        }
    }

    func fighterCard(pokemon: PokemonViewModel, summary: Pokemon, level: Int) -> some View {
        VStack(spacing: DesignKit.Spacing.Primitive.s12) {
            SpriteImage(url: summary.frontSprite)
                .frame(height: 96)

            Text(summary.name)
                .font(.pixel14)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(LocalizedKey("battle.level", level))
                .font(.pixel12)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(level)))
                .animation(DesignKit.Animation.Primitive.snappy, value: level)

            HStack(spacing: DesignKit.Spacing.Primitive.s4) {
                ForEach(pokemon.typeNames, id: \.self) { type in
                    Chip.type(type)
                }
            }

            statGrid(pokemon: pokemon)
        }
        .padding(DesignKit.Spacing.Primitive.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cardBackground)
    }

    func statGrid(pokemon: PokemonViewModel) -> some View {
        let byName = Dictionary(uniqueKeysWithValues: pokemon.stats.map { ($0.stat.name, $0.baseStat) })
        let entries: [(String, Int)] = [
            (Localized("stat.short.hp"), byName["hp"] ?? 0),
            (Localized("stat.short.attack"), byName["attack"] ?? 0),
            (Localized("stat.short.defense"), byName["defense"] ?? 0),
            (Localized("stat.short.specialAttack"), byName["special-attack"] ?? 0),
            (Localized("stat.short.specialDefense"), byName["special-defense"] ?? 0),
            (Localized("stat.short.speed"), byName["speed"] ?? 0)
        ]
        return VStack(spacing: DesignKit.Spacing.Primitive.s2) {
            ForEach(0..<2) { rowIdx in
                HStack(spacing: DesignKit.Spacing.Primitive.s4) {
                    ForEach(0..<3) { colIdx in
                        let (label, value) = entries[rowIdx * 3 + colIdx]
                        HStack(spacing: DesignKit.Spacing.Primitive.s2) {
                            Text(label)
                                .foregroundStyle(.secondary)
                            Text(value, format: .number)
                        }
                        .font(.pixel9)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Type matchup

    var typeMatchup: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
            Text("loadout.typeMatchup")
                .font(.pixel12)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignKit.Spacing.Primitive.s16)

            VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
                matchupLine(
                    fromName: viewModel.playerSummary.name,
                    fromTypes: viewModel.playerPokemon?.typeNames ?? [],
                    toName: viewModel.opponentSummary.name,
                    toTypes: viewModel.opponentPokemon?.typeNames ?? []
                )
                matchupLine(
                    fromName: viewModel.opponentSummary.name,
                    fromTypes: viewModel.opponentPokemon?.typeNames ?? [],
                    toName: viewModel.playerSummary.name,
                    toTypes: viewModel.playerPokemon?.typeNames ?? []
                )
            }
            .padding(DesignKit.Spacing.Primitive.s16)
            .background(Color.cardBackground)
        }
        .padding(.vertical, DesignKit.Spacing.Primitive.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func matchupLine(fromName: String, fromTypes: [String], toName: String, toTypes: [String]) -> some View {
        let chart = PokeBattleKit.loadedTypeChart
        let multipliers = fromTypes.compactMap { chart?.multiplier(attacking: $0, defenders: toTypes) }
        let best = multipliers.max() ?? 1
        return HStack(spacing: DesignKit.Spacing.Primitive.s6) {
            Text(fromName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.forward")
                .font(.pixel9)
                .foregroundStyle(.secondary)
            Text(toName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Chip(TypeEffectiveness.label(for: best), style: TypeEffectiveness.chipStyle(for: best))
        }
        .font(.pixel12)
    }

    // MARK: - Move picker

    var movePicker: some View {
        MovePickerGrid(
            moveSelection: viewModel.selection,
            opponentTypes: viewModel.opponentPokemon?.typeNames ?? []
        )
    }

    // MARK: - Bottom bar

    /// Difficulty menu, plus the Start button once four moves are picked.
    var bottomBar: some View {
        HStack(spacing: DesignKit.Spacing.Primitive.s12) {
            if viewModel.selection.isFull {
                battleButton.transition(.move(edge: .bottom).combined(with: .blurReplace))
            }
            DifficultyMenu()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, DesignKit.Spacing.Primitive.s32)
        .padding(.bottom, DesignKit.Spacing.Primitive.s8)
    }

    var battleButton: some View {
        let phase = viewModel.phase
        return PrimaryCapsuleButton(
            icon: "bolt.fill",
            title: Localized("loadout.start"),
            isEnabled: phase == .readyToStart || phase == .readyToRequest,
            isLoading: phase == .awaitingAI,
            action: phase == .readyToStart
                ? startBattle
                : { Task { await viewModel.requestOpponentLoadout(difficulty: difficulty) } }
        )
    }
}
