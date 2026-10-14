import Observation
import PokeBattleKit

/// Mutable selection state for picking moves before battle. Used by both
/// single-player and multiplayer setup flows.
///
/// Its own observable object (rather than fields on each setup view model)
/// so `MovePickerGrid` can observe just the selection, and so both flows
/// share the toggle/limit/order rules. Selection order is kept so the
/// battle's move grid matches the order the player tapped.
@MainActor
@Observable
final class MoveSelection {
    let maxSelections: Int
    private(set) var pool: [Move] = []
    private(set) var selectedNames: Set<String> = []
    private(set) var selectionOrder: [String] = []

    init(maxSelections: Int = 4) {
        self.maxSelections = maxSelections
    }

    /// Load and rank moves for a Pokemon.
    func load(for pokemon: Pokemon) {
        load(ranked: Self.movesForPokemon(pokemon))
    }

    /// Set pool from pre-ranked moves and reset selection.
    func load(ranked moves: [Move]) {
        pool = moves
        selectedNames = []
        selectionOrder = []
    }

    /// Toggle a move in/out of the selection.
    func toggle(_ move: Move) {
        if selectedNames.contains(move.name) {
            selectedNames.remove(move.name)
            selectionOrder.removeAll { $0 == move.name }
            return
        }
        guard selectedNames.count < maxSelections else { return }
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
    /// All battle-ready moves a Pokemon can learn, ranked by impact.
    static func movesForPokemon(_ pokemon: Pokemon) -> [Move] {
        let names = Set(pokemon.moveNames)
        let pool = PokeBattleKit.allMoves.filter { names.contains($0.name) && $0.isBattleReady }
        return rankedByImpact(pool)
    }

    /// Damage-first sort: damaging moves by power descending, then accuracy.
    static func rankedByImpact(_ moves: [Move]) -> [Move] {
        moves.sorted { lhs, rhs in
            let lDamage = (lhs.power ?? 0) > 0
            let rDamage = (rhs.power ?? 0) > 0
            if lDamage != rDamage { return lDamage }
            let lp = lhs.power ?? 0
            let rp = rhs.power ?? 0
            if lp != rp { return lp > rp }
            return (lhs.accuracy ?? 100) > (rhs.accuracy ?? 100)
        }
    }

    /// Resolves an ordered list of selected moves from a pool.
    static func resolve(selectionOrder: [String], from pool: [Move]) -> [Move] {
        let byName = Dictionary(pool.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
        return selectionOrder.compactMap { byName[$0] }
    }
}
