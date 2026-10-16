import Foundation
import SwiftData
import PokeBattleKit

/// A form's base species learnset, for forms whose own PokeAPI learnset is
/// too small to battle with (many Mega and G-Max forms).
@MainActor
protocol BaseFormLookup {
    /// The move names of `pokemon`'s base species, or `nil` if it has none.
    func baseFormMoveNames(of pokemon: Pokemon) -> [String]?
}

/// `BaseFormLookup` backed by the SwiftData store.
@MainActor
struct StoreBaseFormLookup: BaseFormLookup {
    let modelContext: ModelContext

    func baseFormMoveNames(of pokemon: Pokemon) -> [String]? {
        for name in PokemonForms.baseNames(of: pokemon.name) {
            let descriptor = FetchDescriptor<Pokemon>(predicate: #Predicate { $0.name == name })
            if let base = try? modelContext.fetch(descriptor).first, !base.moveNames.isEmpty {
                return base.moveNames
            }
        }
        return nil
    }
}

/// Builds a Pokémon's move pool for the loadout screen: every battle-ready
/// move it can learn, ranked by impact.
///
/// Follows PokeBattleKit's rules so every Pokémon can battle: a form with
/// too few usable moves also gets its base species' moves (`PokemonForms`),
/// and a Pokémon with no usable attack gets Struggle.
@MainActor
struct MovePoolBuilder {
    let catalog: any BattleCatalogReading
    let baseForms: BaseFormLookup

    func moves(for pokemon: Pokemon) -> [Move] {
        let allMoves = catalog.allMoves
        var names = Set(pokemon.moveNames)
        if battleReady(names, in: allMoves).count < PokemonForms.minimumOwnMoves,
           let baseMoves = baseForms.baseFormMoveNames(of: pokemon) {
            names.formUnion(baseMoves)
        }
        let pool = LoadoutStrategy.withFallbackAttack(battleReady(names, in: allMoves), struggle: catalog.move(named: "struggle"))
        return Self.rankedByImpact(pool)
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
}

// MARK: - Private
private extension MovePoolBuilder {
    func battleReady(_ names: Set<String>, in allMoves: [Move]) -> [Move] {
        allMoves.filter { names.contains($0.name) && $0.isBattleReady }
    }
}
