import PokeBattleKit

/// SwiftData bridge: builds a ``Candidate`` from a persistence
/// model. The struct itself lives in PokeBattleKit.
extension Candidate {
    init(pokemon: Pokemon, fallbackTypes: [String] = []) {
        let types = pokemon.types.map(\.type.name)
        self.init(
            id: pokemon.id,
            name: pokemon.name,
            typeNames: types.isEmpty ? fallbackTypes : types,
            baseStatTotal: pokemon.stats.map(\.baseStat).reduce(0, +),
            isLegendary: pokemon.isLegendary,
            isMythical: pokemon.isMythical
        )
    }
}
