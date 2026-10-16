import Foundation
import Observation
import PokeBattleKit

/// Mutable selection state for picking moves before battle. Used by both
/// single-player and multiplayer setup flows; the pool itself comes from
/// `MovePoolBuilder`.
///
/// Its own observable object (rather than fields on each setup view model)
/// so `MovePickerGrid` can observe just the selection, and so both flows
/// share the toggle/limit/order rules. Selection order is kept so the
/// battle's move grid matches the order the player tapped.
@MainActor
@Observable
final class MoveSelection {
    /// Most moves a loadout can hold.
    let loadoutSize: Int
    private(set) var pool: [Move] = []
    private(set) var selectedNames: Set<String> = []
    private(set) var selectionOrder: [String] = []
    /// The suggested loadout, if one was given (see `recommend(_:)`).
    private(set) var recommendedNames: [String] = []
    /// Bumped when a tap can't add a move because the loadout is full, so
    /// the grid can show a hint and play a haptic.
    private(set) var fullTapCount = 0

    init(loadoutSize: Int = 4) {
        self.loadoutSize = loadoutSize
    }

    /// Moves to pick: a full loadout, or the whole pool for a Pokémon that
    /// knows fewer usable moves (Magikarp), as in the games.
    var maxSelections: Int { min(loadoutSize, max(1, pool.count)) }

    /// Set pool from pre-ranked moves and reset selection.
    func load(ranked moves: [Move]) {
        pool = moves
        selectedNames = []
        selectionOrder = []
        recommendedNames = []
    }

    /// Selects `moves` (in order, up to the limit) and remembers them as the
    /// recommendation, so the player can reset to them after changing moves.
    /// The recommended moves also move to the front of the pool, ahead of
    /// the rest in their existing order. Moves not in the pool are ignored.
    func recommend(_ moves: [Move]) {
        let available = Set(pool.map(\.name))
        recommendedNames = Array(moves.map(\.name).filter(available.contains).prefix(maxSelections))
        let recommended = Set(recommendedNames)
        pool = Self.resolve(selectionOrder: recommendedNames, from: pool)
            + pool.filter { !recommended.contains($0.name) }
        resetToRecommended()
    }

    /// Restores the recommended loadout.
    func resetToRecommended() {
        selectedNames = Set(recommendedNames)
        selectionOrder = recommendedNames
    }

    /// Whether the current selection is the recommended one.
    var isRecommended: Bool {
        !recommendedNames.isEmpty && Set(recommendedNames) == selectedNames
    }

    /// Toggle a move in/out of the selection.
    func toggle(_ move: Move) {
        if selectedNames.contains(move.name) {
            selectedNames.remove(move.name)
            selectionOrder.removeAll { $0 == move.name }
            return
        }
        guard selectedNames.count < maxSelections else {
            fullTapCount += 1
            return
        }
        selectedNames.insert(move.name)
        selectionOrder.append(move.name)
    }

    /// Resolved moves in selection order.
    var selectedMoves: [Move] {
        Self.resolve(selectionOrder: selectionOrder, from: pool)
    }

    var isFull: Bool { selectedNames.count == maxSelections }
}

// MARK: - Static utilities
extension MoveSelection {
    /// Resolves an ordered list of selected moves from a pool.
    static func resolve(selectionOrder: [String], from pool: [Move]) -> [Move] {
        let byName = Dictionary(pool.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
        return selectionOrder.compactMap { byName[$0] }
    }
}
