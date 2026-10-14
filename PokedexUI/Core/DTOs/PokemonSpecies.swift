import Foundation

/// `/pokemon-species/{id}` payload. Merged into a `Pokemon` row by
/// `PokedexStore` at import time so the detail view can read
/// habitat, flavor text, evolution chain id, genus, gender + capture rate,
/// and the legendary/mythical flags from one model.
struct PokemonSpecies: Decodable, Sendable {
    let habitat: APINamed?
    let flavorTextEntries: [FlavorTextEntry]
    let varieties: [Variety]
    let genera: [Genus]
    let genderRate: Int
    let captureRate: Int
    let baseHappiness: Int?
    let generation: APINamed?
    let evolutionChain: EvolutionChainRef?
    let isLegendary: Bool
    let isMythical: Bool

    var defaultVariety: Variety? {
        varieties.first(where: \.isDefault) ?? varieties.first
    }

    var englishFlavorText: String? {
        flavorTextEntries
            .first(where: { $0.language.name == "en" })?
            .flavorText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{000C}", with: " ")
    }

    var englishGenus: String? {
        genera.first(where: { $0.language.name == "en" })?.genus
    }
}

/// Bare-bones `{ name }` envelope used by nested PokeAPI references that
/// don't carry a URL.
struct APINamed: Decodable, Sendable {
    let name: String
}

/// One pokedex flavor-text entry. PokeAPI ships one per game version per
/// language; we filter to English at read time via `englishFlavorText`.
struct FlavorTextEntry: Decodable, Sendable {
    let flavorText: String
    let language: APINamed
}

/// Localized genus label (e.g. "Mouse Pokémon" for Pikachu).
struct Genus: Decodable, Sendable {
    let genus: String
    let language: APINamed
}

/// Reference to a `/evolution-chain/{id}` resource. The id is the trailing
/// path component; `EvolutionService` resolves the full chain on demand.
struct EvolutionChainRef: Decodable, Sendable {
    let url: String

    /// Last path component is the chain id.
    var id: String? {
        URL(string: url)?
            .pathComponents
            .last(where: { !$0.isEmpty && $0 != "/" })
    }
}

/// One form of a species. PokemonSpecies returns multiple varieties for
/// pokemon with alt forms; PokedexUI picks the default.
struct Variety: Decodable, Sendable {
    let isDefault: Bool
    let pokemon: PokemonReference

    struct PokemonReference: Decodable, Sendable {
        let name: String
        let url: String
    }
}
