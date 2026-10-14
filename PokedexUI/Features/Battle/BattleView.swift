import SwiftUI
import PokeBattleKit

/// Gameboy-styled turn-based battle screen.
struct BattleView<ViewModel: BattleViewModelProtocol>: View {
    @State var viewModel: ViewModel

    var body: some View {
        content
            .applyPokedexStyling(
                title: "\(viewModel.playerName) vs \(viewModel.opponentName)",
                navColor: .darkGrey
            )
            .foregroundStyle(.white)
            .task { await viewModel.prepare() }
            .battleFeedback(animator: viewModel.animator)
            .sensoryFeedback(trigger: viewModel.winner) { _, new in
                switch new {
                case .player: return .success
                case .opponent: return .error
                case .none: return nil
                }
            }
    }

}

// MARK: - Private
private extension BattleView {
    @ViewBuilder
    var content: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.secondary)
                .font(.pixel14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .lineHeight(.loose)
        } else if let state = viewModel.state {
            battleLayout(state: state)
        }
    }

    func battleLayout(state: BattleState) -> some View {
        VStack(spacing: 0) {
            Spacer()
            BattleArena(
                state: state,
                animator: viewModel.animator,
                winner: viewModel.winner
            )
            .padding()
            BattleLogFeed(log: viewModel.log)
                .padding(.horizontal)
            moveGrid(state: state)
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, 24.0)
    }

    func moveGrid(state: BattleState) -> some View {
        let disabled = !viewModel.canSelectMove || viewModel.isResolvingTurn || viewModel.winner != nil
        return LazyVGrid(columns: GridLayout.two.layout, spacing: GridLayout.two.spacing) {
            ForEach(viewModel.displayMoves, id: \.name) { move in
                Button {
                    Task { await viewModel.submit(move) }
                } label: {
                    MoveCell(move: move, mode: .battle, effectiveness: viewModel.effectiveness(for: move))
                        .equatable()
                }
                .disabled(disabled)
                .sensoryFeedback(.impact(weight: .light), trigger: viewModel.isResolvingTurn)
            }
        }
        .disabled(disabled)
        .opacity(disabled ? Opacity.disabled : 1)
        .animation(.easeInOut(duration: 0.2), value: disabled)
    }
}

/// Opponent and player rows (HP card + sprite). Its own view so per-frame
/// animator cues invalidate only the arena, not the log feed or move grid.
private struct BattleArena: View {
    let state: BattleState
    let animator: BattleAnimator
    let winner: Side?

    var body: some View {
        VStack(spacing: 42.0) {
            HStack(alignment: .top) {
                hpCard(state.opponent, side: .opponent)
                Spacer(minLength: 28)
                sprite(url: state.opponent.frontSpriteURL, side: .opponent)
                    .padding(.horizontal)
            }
            HStack(alignment: .bottom) {
                sprite(url: playerSpriteURL, side: .player)
                    .padding(.horizontal)
                Spacer(minLength: 28)
                hpCard(state.player, side: .player)
            }
        }
    }
}

// MARK: - Private
private extension BattleArena {
    var playerSpriteURL: String? {
        if winner == .player {
            return state.player.frontSpriteURL
        }
        return state.player.backSpriteURL ?? state.player.frontSpriteURL
    }

    func sprite(url: String?, side: Side) -> some View {
        let cues = animator.cues(for: side)
        return BattlerSprite(
            url: url,
            side: side,
            isAttacking: animator.attackingSide == side,
            isFainted: animator.faintedSide == side,
            hasEntered: animator.hasEntered,
            shakeTick: cues.shakeTick,
            damageAmount: cues.damageAmount,
            damageTick: cues.damageTick,
            isWinner: winner == side
        )
    }

    func hpCard(_ c: Combatant, side: Side) -> some View {
        VStack(alignment: side == .opponent ? .leading : .trailing, spacing: 8) {
            if side == .opponent {
                typeChips(c.typeNames)
            }
            HPCard(
                name: c.name,
                currentHP: c.currentHP,
                maxHP: c.maxHP,
                status: c.status
            )
            .equatable()
            if side == .player {
                typeChips(c.typeNames)
            }
        }
    }

    func typeChips(_ types: [String]) -> some View {
        HStack {
            ForEach(types, id: \.self) { type in
                Chip.type(type)
            }
        }
    }
}

/// Haptics driven by animator ticks. Reading the ticks here keeps them out
/// of `BattleView`'s body, so a tick doesn't re-evaluate the whole screen.
private struct BattleFeedbackModifier: ViewModifier {
    let animator: BattleAnimator

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.impact(weight: .medium), trigger: animator.attackTick)
            .sensoryFeedback(.success, trigger: animator.opponentCues.shakeTick)
            .sensoryFeedback(.error, trigger: animator.playerCues.shakeTick)
    }
}

private extension View {
    func battleFeedback(animator: BattleAnimator) -> some View {
        modifier(BattleFeedbackModifier(animator: animator))
    }
}

#Preview {
    NavigationStack {
        TabView {
            BattleView(
                viewModel: BattleViewModel(
                    player: PokemonViewModel(pokemon: .pikachu),
                    opponent: PokemonViewModel(pokemon: .pikachu),
                    playerMoves: Array(PokeBattleKit.allMoves.prefix(4)),
                    opponentMoves: Array(PokeBattleKit.allMoves.prefix(4)),
                    container: .live
                )
            )
        }
        .applyPokedexStyling(title: "Battle", navColor: .darkGrey)
    }
    .colorScheme(.dark)
}
