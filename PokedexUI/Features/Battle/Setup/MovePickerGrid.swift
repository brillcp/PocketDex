import SwiftUI
import PokeBattleKit

/// Reusable move selection grid shared by single-player and multiplayer
/// loadout screens.
///
/// One grid of every move in the pool's order: the recommended loadout
/// first (pre-selected), then the rest, best first for this matchup when
/// the setup ranked it. Tapping a card toggles it in place with a selection
/// tick, so the grid never reshuffles. The header shows the count and, when
/// there's a recommendation, either a "Recommended" chip or a button to
/// reset to it. Nothing is dimmed when the loadout is full; tapping another
/// move then shows a hint instead.
struct MovePickerGrid: View {
    let moveSelection: MoveSelection
    var opponentTypes: [String] = []

    @State private var showsFullHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
            header.padding(.horizontal, DesignKit.Spacing.Primitive.s16)
            LazyVGrid(columns: GridLayout.two.layout, spacing: GridLayout.two.spacing) {
                ForEach(moveSelection.pool, id: \.name) { move in
                    MovePickerCard(
                        move: move,
                        selected: moveSelection.selectedNames.contains(move.name),
                        effectiveness: effectiveness(of: move),
                        moveSelection: moveSelection
                    )
                }
            }
        }
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
    var header: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s4) {
            HStack(spacing: DesignKit.Spacing.Primitive.s8) {
                Text("Moves \(moveSelection.selectedNames.count)/\(moveSelection.maxSelections)")
                if moveSelection.isRecommended {
                    Chip("Recommended", style: .primary, size: .small)
                }
                Spacer()
                if !moveSelection.recommendedNames.isEmpty, !moveSelection.isRecommended {
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        withAnimation(DesignKit.Animation.Primitive.snappy25) { moveSelection.resetToRecommended() }
                    }
                    .accessibilityLabel("Reset to recommended moves")
                }
            }
            if showsFullHint {
                Text("Remove one of your moves to add another")
                    .font(.pixel9)
                    .foregroundStyle(Color.pokedexRed)
                    .transition(.opacity)
            }
        }
        .font(.pixel12)
        .foregroundStyle(.secondary)
    }

    func effectiveness(of move: Move) -> Double? {
        opponentTypes.isEmpty ? nil : PokeBattleKit.loadedTypeChart?.multiplier(attacking: move.typeName, defenders: opponentTypes)
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
        .sensoryFeedback(.selection, trigger: selected)
    }
}
