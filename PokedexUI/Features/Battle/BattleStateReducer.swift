import PokeBattleKit

/// Applies a battle event to a state snapshot and posts damage cues to the
/// animator. Shared by both single-player and multiplayer battle VMs to
/// eliminate duplicated state-mutation logic.
///
/// This lets the HUD update event by event as the turn plays out (HP drops
/// as each hit lands) instead of jumping to the end-of-round state. The
/// engine stays the source of truth where one exists: single-player and the
/// multiplayer host re-sync to its state after the turn. The multiplayer
/// guest has no engine, so for it the reduced state is the state.
@MainActor
enum BattleStateReducer {
    static func apply(_ event: Event, to state: inout BattleState, animator: BattleAnimator) {
        switch event {
        case .damaged(let side, let amount, _, _),
             .statusTick(let side, _, let amount),
             .recoil(let side, let amount):
            mutate(side, in: &state) { $0.currentHP = max(0, $0.currentHP - amount) }
            animator.postDamage(side: side, amount: amount)
        case .healed(let side, let amount):
            mutate(side, in: &state) { $0.currentHP = min($0.maxHP, $0.currentHP + amount) }
        case .statusApplied(let side, let status):
            mutate(side, in: &state) {
                $0.status = status
                if status == .sleep { $0.sleepTurns = 2 }
            }
        case .thawed(let side):
            mutate(side, in: &state) { $0.status = Status.none }
        case .wokeUp(let side):
            mutate(side, in: &state) { $0.status = Status.none; $0.sleepTurns = 0 }
        case .statChanged(let side, let stat, let delta):
            mutate(side, in: &state) { $0.applyStage(stat, delta: delta) }
        case .used, .missed, .fullyParalyzed, .fastAsleep, .frozenSolid, .recharging, .lostFocus,
             .flinched, .failed, .hitCount, .fainted, .ended:
            break
        }
    }
}

// MARK: - Private
private extension BattleStateReducer {
    static func mutate(_ side: Side, in state: inout BattleState, _ body: (inout Combatant) -> Void) {
        if side == .player {
            body(&state.player)
        } else {
            body(&state.opponent)
        }
    }
}
