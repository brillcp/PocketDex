import SwiftUI
import PokeBattleKit

/// Per-side animation cue bundle.
///
/// The `...Tick` counters are triggers, not values: bumping one fires a
/// one-shot effect even when the same amount repeats. `shakeTick` animates
/// `ShakeEffect` through one full wave and drives hit haptics; `damageTick`
/// gives each `DamagePopup` a fresh identity so it replays.
struct SideCues: Equatable {
    var shakeTick: Int = 0
    var damageAmount: Int?
    var damageTick: Int = 0
    var color: Color?
}

/// Owns all animation cues the battle UI reads.
///
/// Kept separate from the battle state so the view models can drive
/// presentation (who's lunging, who fainted, sprite tint) without touching
/// the engine's `BattleState`. Each `play...` method sets a cue and then
/// sleeps for roughly the animation's length, so the view model's `await`
/// sequences events one after another.
@MainActor
@Observable
final class BattleAnimator {
    var attackingSide: Side?
    var faintedSide: Side?
    var hasEntered: Bool = false
    var playerCues:   SideCues = SideCues()
    var opponentCues: SideCues = SideCues()
    var attackTick: Int = 0

    func cues(for side: Side) -> SideCues {
        side == .player ? playerCues : opponentCues
    }

    func mutateCues(_ side: Side, _ body: (inout SideCues) -> Void) {
        switch side {
        case .player:   body(&playerCues)
        case .opponent: body(&opponentCues)
        }
    }

    func playEntrance() async {
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(DesignKit.Animation.Primitive.spring60d75) {
            hasEntered = true
        }
    }

    func playAttack(side: Side) async {
        withAnimation(DesignKit.Animation.Primitive.easeOut10) { attackingSide = side }
        try? await Task.sleep(for: .milliseconds(110))
        withAnimation(DesignKit.Animation.Primitive.spring18d40) { attackingSide = nil }
    }

    func playHit(side: Side, amount: Int, effectiveness: Double) async {
        if effectiveness > 0, amount > 0 {
            mutateCues(side) { $0.shakeTick += 1 }
        }
        try? await Task.sleep(for: .milliseconds(250))
    }

    func playRecoil(side: Side, amount: Int) async {
        if amount > 0 {
            mutateCues(side) { $0.shakeTick += 1 }
        }
        try? await Task.sleep(for: .milliseconds(250))
    }

    func playFaint(side: Side) async {
        withAnimation(DesignKit.Animation.Primitive.easeIn50) { faintedSide = side }
        try? await Task.sleep(for: .milliseconds(450))
    }

    func postDamage(side: Side, amount: Int) {
        guard amount > 0 else { return }
        mutateCues(side) {
            $0.damageAmount = amount
            $0.damageTick += 1
        }
    }

    /// Route a `Event` to the matching animation cue. Events that
    /// don't drive a sprite/HUD change (status text, etc.) no-op here.
    func play(_ event: Event) async {
        switch event {
        case .used(let side, _):
            await playAttack(side: side)
        case .damaged(let side, let amount, let effectiveness, _):
            await playHit(side: side, amount: amount, effectiveness: effectiveness)
        case .recoil(let side, let amount):
            await playRecoil(side: side, amount: amount)
        case .fainted(let side):
            await playFaint(side: side)
        default:
            break
        }
    }
}
