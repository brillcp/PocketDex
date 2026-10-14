import SwiftUI
import PokeBattleKit

/// Reusable move selection grid shared by single-player and multiplayer
/// loadout screens. Displays a counter header and a two-column grid of
/// move cards with toggle selection.
struct MovePickerGrid: View {
    let moveSelection: MoveSelection
    var opponentTypes: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MovePickerHeader(
                selectedCount: moveSelection.selectedNames.count,
                maxSelections: moveSelection.maxSelections
            )
            grid
        }
    }
}

// MARK: - Private
private extension MovePickerGrid {
    var grid: some View {
        LazyVGrid(columns: GridLayout.two.layout, spacing: GridLayout.two.spacing) {
            ForEach(moveSelection.pool, id: \.name, content: moveCard)
        }
    }

    func moveCard(_ move: Move) -> some View {
        let selected = moveSelection.selectedNames.contains(move.name)
        let atCap = !selected && moveSelection.selectedNames.count >= moveSelection.maxSelections
        let effectiveness: Double? = opponentTypes.isEmpty
            ? nil
            : PokeBattleKit.typeChart.multiplier(attacking: move.typeName, defenders: opponentTypes)
        return MovePickerCard(
            move: move,
            selected: selected,
            atCap: atCap,
            effectiveness: effectiveness,
            moveSelection: moveSelection
        )
    }
}

/// "selected/max" counter above the grid.
private struct MovePickerHeader: View {
    let selectedCount: Int
    let maxSelections: Int

    var body: some View {
        Text("\(selectedCount)/\(maxSelections)")
            .font(.pixel12)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }
}

/// Toggleable move card. Takes narrow values so only cards whose selection
/// or cap state changed re-run their body when the selection updates.
/// `moveSelection` is only used in the tap action, never read in `body`, so
/// it doesn't make every card observe the whole selection.
private struct MovePickerCard: View {
    let move: Move
    let selected: Bool
    let atCap: Bool
    let effectiveness: Double?
    let moveSelection: MoveSelection

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                moveSelection.toggle(move)
            }
        } label: {
            MoveCell(move: move, mode: .loadout(selected: selected), effectiveness: effectiveness)
        }
        .buttonStyle(.plain)
        .opacity(atCap ? Opacity.disabled : 1)
        .disabled(atCap)
        .sensoryFeedback(.impact(weight: .light), trigger: selected)
    }
}
