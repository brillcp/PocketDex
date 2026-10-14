import SwiftUI
import PokeBattleKit

/// Reusable loadout screen showing a pokemon summary card, a move picker
/// grid, and a caller-provided bottom bar button. Used by both
/// single-player and multiplayer loadout flows.
struct MoveLoadoutView<BottomBar: View>: View {
    let pokemon: Pokemon
    let moveSelection: MoveSelection
    var opponentTypes: [String] = []
    var isDisabled: Bool = false
    @ViewBuilder let bottomBar: () -> BottomBar

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MoveLoadoutSummary(pokemon: pokemon)
                MovePickerGrid(
                    moveSelection: moveSelection,
                    opponentTypes: opponentTypes
                )
            }
        }
        .scrollIndicators(.hidden)
        .disabled(isDisabled)
        .opacity(isDisabled ? Opacity.disabled : 1)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
        .safeAreaBar(edge: .bottom) {
            if moveSelection.isFull {
                bottomBar().transition(.move(edge: .bottom).combined(with: .blurReplace))
            }
        }
        .animation(.snappy(duration: 0.2), value: moveSelection.isFull)
    }
}

// MARK: - Private
/// Sprite, name, and type chips for the pokemon being configured. A separate
/// view so loadout changes (selection, disabled state) don't re-run it.
private struct MoveLoadoutSummary: View {
    let pokemon: Pokemon

    var body: some View {
        HStack(spacing: 12) {
            SpriteImage(url: pokemon.frontSprite)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(pokemon.name)
                    .font(.pixel14)
                HStack(spacing: 4) {
                    ForEach(pokemon.types) { type in
                        Chip.type(type)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.cardBackground)
    }
}
