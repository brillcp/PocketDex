import Foundation
import Observation
import SwiftData
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

    /// Load and rank moves for a Pokemon.
    func load(for pokemon: Pokemon, catalog: BattleCatalog) {
        load(ranked: Self.movesForPokemon(pokemon, catalog: catalog))
    }

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
    /// All battle-ready moves a Pokemon can learn, ranked by impact.
    ///
    /// Follows PokeBattleKit's rules so every Pokémon can battle: a form
    /// with too few usable moves (many Mega and G-Max forms in PokeAPI)
    /// also gets its base species' moves (`PokemonForms`), and a Pokémon
    /// with no usable attack gets Struggle.
    static func movesForPokemon(_ pokemon: Pokemon, catalog: BattleCatalog) -> [Move] {
        let allMoves = catalog.allMoves
        var names = Set(pokemon.moveNames)
        if battleReady(names, in: allMoves).count < PokemonForms.minimumOwnMoves,
           let base = baseForm(of: pokemon) {
            names.formUnion(base.moveNames)
        }
        let pool = LoadoutStrategy.withFallbackAttack(battleReady(names, in: allMoves), struggle: catalog.move(named: "struggle"))
        return rankedByImpact(pool)
    }

    private static func battleReady(_ names: Set<String>, in allMoves: [Move]) -> [Move] {
        allMoves.filter { names.contains($0.name) && $0.isBattleReady }
    }

    /// The form's base species from the same store, if it has a learnset.
    private static func baseForm(of pokemon: Pokemon) -> Pokemon? {
        guard let context = pokemon.modelContext else { return nil }
        for name in PokemonForms.baseNames(of: pokemon.name) {
            let descriptor = FetchDescriptor<Pokemon>(predicate: #Predicate { $0.name == name })
            if let base = try? context.fetch(descriptor).first, !base.moveNames.isEmpty { return base }
        }
        return nil
    }

    /// Damage-first sort: damaging moves by power descending, then accuracy.
    static func rankedByImpact(_ moves: [Move]) -> [Move] {
        moves.sorted { lhs, rhs in
            let lDamage = lhs.isDamage
            let rDamage = rhs.isDamage
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
