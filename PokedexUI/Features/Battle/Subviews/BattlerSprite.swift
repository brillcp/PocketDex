import SwiftUI
import PokeBattleKit

/// One combatant's animated sprite with lunge, shake, faint, and victory effects.
///
/// Takes plain values (not the animator) so it only re-renders when its
/// own side's cues change.
struct BattlerSprite: View {
    let url: String?
    let side: Side
    let isAttacking: Bool
    let isFainted: Bool
    let hasEntered: Bool
    let shakeTick: Int
    let damageAmount: Int?
    let damageTick: Int
    let isWinner: Bool

    @State private var celebratingTilt: Double = 0

    var body: some View {
        SpriteImage(url: url)
            .frame(width: 120, height: 148)
        .modifier(ShakeEffect(progress: CGFloat(shakeTick)))
        .rotationEffect(.degrees(celebratingTilt))
        .offset(
            x: lungeOffset.width + entryOffset,
            y: lungeOffset.height
        )
        .opacity(isFainted ? 0 : 1)
        .overlay(alignment: .top) { damagePopup }
        .animation(DesignKit.Animation.Primitive.spring35d50, value: shakeTick)
        .animation(DesignKit.Animation.Primitive.easeOut50, value: isFainted)
        .onChange(of: isWinner) { _, newValue in
            if newValue {
                withAnimation(DesignKit.Animation.Primitive.bouncy35.repeatForever(autoreverses: true)) {
                    celebratingTilt = 10
                }
            } else {
                withAnimation(DesignKit.Animation.Primitive.default) { celebratingTilt = 0 }
            }
        }
    }
}

// MARK: - Private
private extension BattlerSprite {
    /// Off-screen toward the owner's edge before entrance and after fainting.
    var entryOffset: CGFloat {
        if isFainted {
            return side == .player ? -200 : 200
        }
        return hasEntered ? 0 : (side == .player ? -200 : 200)
    }

    var lungeOffset: CGSize {
        guard isAttacking else { return .zero }
        return side == .player
            ? CGSize(width: 20, height: -10)
            : CGSize(width: -20, height: 10)
    }

    @ViewBuilder
    var damagePopup: some View {
        if let amount = damageAmount, damageTick > 0 {
            DamagePopup(amount: amount)
                .id(damageTick)
        }
    }
}

/// Single-shot floating damage label that animates up and fades on appear.
private struct DamagePopup: View {
    private let baseOffset: CGSize = CGSize(width: 0, height: DesignKit.Spacing.Primitive.s24)

    let amount: Int

    @State private var verticalOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Text("-\(amount)")
            .font(.pixel14)
            .foregroundStyle(Color.pokedexRed)
            .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
            .offset(x: baseOffset.width, y: baseOffset.height + verticalOffset)
            .opacity(opacity)
            .onAppear {
                verticalOffset = 0
                opacity = 1
                withAnimation(DesignKit.Animation.Primitive.easeOut120) {
                    verticalOffset = -48
                    opacity = 0
                }
            }
    }
}
