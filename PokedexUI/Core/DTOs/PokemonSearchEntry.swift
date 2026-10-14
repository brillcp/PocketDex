/// Precomputed full-text search haystack for one pokemon, built off the
/// main actor by `PokedexStore`.
struct PokemonSearchEntry: Sendable {
    let id: Int
    let haystack: String
}
