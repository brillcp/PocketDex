import PokeBattleKit

extension Event {
    /// The event seen from the other side: the host resolves rounds from its
    /// own perspective, and the guest plays them mirrored so its own fighter
    /// is always `.player`.
    var mirrored: Event {
        switch self {
        case .used(let s, let m): .used(s.opposite, moveName: m)
        case .missed(let s): .missed(s.opposite)
        case .damaged(let s, let a, let e, let c): .damaged(s.opposite, amount: a, effectiveness: e, crit: c)
        case .statusApplied(let s, let st): .statusApplied(s.opposite, st)
        case .statusTick(let s, let st, let a): .statusTick(s.opposite, st, amount: a)
        case .statChanged(let s, let st, let d): .statChanged(s.opposite, stat: st, delta: d)
        case .healed(let s, let a): .healed(s.opposite, amount: a)
        case .recoil(let s, let a): .recoil(s.opposite, amount: a)
        case .recharging(let s): .recharging(s.opposite)
        case .wokeUp(let s): .wokeUp(s.opposite)
        case .fastAsleep(let s): .fastAsleep(s.opposite)
        case .frozenSolid(let s): .frozenSolid(s.opposite)
        case .thawed(let s): .thawed(s.opposite)
        case .fullyParalyzed(let s): .fullyParalyzed(s.opposite)
        case .lostFocus(let s): .lostFocus(s.opposite)
        case .flinched(let s): .flinched(s.opposite)
        case .failed(let s): .failed(s.opposite)
        case .hitCount(let s, let n): .hitCount(s.opposite, count: n)
        case .fainted(let s): .fainted(s.opposite)
        case .ended(let w): .ended(winner: w?.opposite)
        }
    }
}
