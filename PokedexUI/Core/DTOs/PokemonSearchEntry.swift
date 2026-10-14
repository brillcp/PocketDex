/// Precomputed full-text search haystack for one pokemon, built off the
/// main actor by `PokedexStore`. A plain Sendable value, so the main actor
/// never has to walk every row's relationships to build the index;
/// `SearchViewModel` pairs entries with its own rows by `id`.
struct PokemonSearchEntry: Sendable {
    let id: Int
    let haystack: String
}
