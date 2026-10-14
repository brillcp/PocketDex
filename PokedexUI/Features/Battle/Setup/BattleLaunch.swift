import Foundation

/// Payload for navigating from setup to battle, carrying a pre-built view model.
///
/// Setup runs in a sheet but the battle is pushed onto the detail screen's
/// stack after the sheet dismisses, so the fully configured view model is
/// handed across in this value. Equality and hashing use only `id` (the
/// view model isn't `Hashable`), which is all `navigationDestination(item:)`
/// needs.
struct BattleLaunch: Identifiable, Hashable {
    let id = UUID()
    let viewModel: BattleViewModel

    static func == (lhs: BattleLaunch, rhs: BattleLaunch) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
