import SwiftUI
import PokeBattleKit

/// Reusable move selection grid shared by single-player and multiplayer
/// loadout screens.
///
/// Two sections, so the loadout is always visible at the top:
/// - **Your moves**: the selected moves, in the order they were picked.
///   When the selection came from a recommendation, the header says so and
///   offers to reset to it after changes.
/// - **Other moves**: everything else, in the pool's order (best first for
///   this matchup when the setup ranked it).
///
/// Tapping a move moves it between the sections. Nothing is dimmed when the
/// loadout is full; tapping another move then shows a hint instead.
struct MovePickerGrid: View {
    let moveSelection: MoveSelection
    var opponentTypes: [String] = []

    @State private var showsFullHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s16) {
            section(header: yourMovesHeader, moves: moveSelection.selectedMoves, selected: true)
            if !moveSelection.unselectedMoves.isEmpty {
                section(header: otherMovesHeader, moves: moveSelection.unselectedMoves, selected: false)
            }
        }
        .animation(DesignKit.Animation.Primitive.snappy25, value: moveSelection.selectionOrder)
        .sensoryFeedback(.warning, trigger: moveSelection.fullTapCount)
        .onChange(of: moveSelection.fullTapCount) {
            withAnimation(DesignKit.Animation.Primitive.easeOut20) { showsFullHint = true }
        }
        .onChange(of: moveSelection.selectedNames.count) {
            withAnimation(DesignKit.Animation.Primitive.easeOut20) { showsFullHint = false }
        }
    }
}

// MARK: - Private
private extension MovePickerGrid {
    func section(header: some View, moves: [Move], selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
            header.padding(.horizontal, DesignKit.Spacing.Primitive.s16)
            LazyVGrid(columns: GridLayout.two.layout, spacing: GridLayout.two.spacing) {
                ForEach(moves, id: \.name) { move in
                    MovePickerCard(
                        move: move,
                        selected: selected,
                        effectiveness: effectiveness(of: move),
                        moveSelection: moveSelection
                    )
                }
            }
        }
    }

    var yourMovesHeader: some View {
        HStack(spacing: DesignKit.Spacing.Primitive.s8) {
            Text("Your moves \(moveSelection.selectedNames.count)/\(moveSelection.maxSelections)")
            if moveSelection.isRecommended {
                Chip("Recommended", style: .primary, size: .small)
            }
            Spacer()
            if !moveSelection.recommendedNames.isEmpty, !moveSelection.isRecommended {
                Button("Reset") {
                    withAnimation(DesignKit.Animation.Primitive.snappy25) { moveSelection.resetToRecommended() }
                }
                .font(.pixel12)
            }
        }
        .font(.pixel12)
        .foregroundStyle(.secondary)
    }

    var otherMovesHeader: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s4) {
            Text(moveSelection.recommendedNames.isEmpty ? "Other moves" : "Other moves, best first")
                .font(.pixel12)
                .foregroundStyle(.secondary)
            if showsFullHint {
                Text("Remove one of your moves to add another")
                    .font(.pixel9)
                    .foregroundStyle(Color.pokedexRed)
                    .transition(.opacity)
            }
        }
    }

    func effectiveness(of move: Move) -> Double? {
        opponentTypes.isEmpty ? nil : PokeBattleKit.typeChartIfLoaded?.multiplier(attacking: move.typeName, defenders: opponentTypes)
    }
}

/// Toggleable move card. Takes narrow values so only cards whose selection
/// changed re-run their body when the selection updates. `moveSelection` is
/// only used in the tap action, never read in `body`, so it doesn't make
/// every card observe the whole selection.
private struct MovePickerCard: View {
    let move: Move
    let selected: Bool
    let effectiveness: Double?
    let moveSelection: MoveSelection

    var body: some View {
        Button {
            withAnimation(DesignKit.Animation.Primitive.snappy25) {
                moveSelection.toggle(move)
            }
        } label: {
            MoveCell(move: move, mode: .loadout(selected: selected), effectiveness: effectiveness)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: selected)
    }
}
