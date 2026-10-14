/// Sendable decoding payloads for PokeAPI responses. These are what cross
/// from the network into `PokedexStore`; the `@Model` classes are built
/// from them on the store's background context.
///
/// Property names mirror the JSON in camelCase; `JSONDecoder.pokeAPI()`
/// maps PokeAPI's snake_case keys, so no `CodingKeys` are needed.

/// Generic `{ name, url }` reference used across PokeAPI payloads.
struct APIRef: Decodable, Sendable, Hashable {
    let name: String
    let url: String
}

/// Paginated PokeAPI list envelope containing `{ count, results }`.
struct APIListResponse: Decodable, Sendable {
    let count: Int?
    let results: [APIRef]
}

/// `/pokemon/{id}` detail payload.
struct PokemonDTO: Decodable, Sendable {
    struct Sprites: Decodable, Sendable {
        let frontDefault: String
        let backDefault: String?
    }

    struct Cries: Decodable, Sendable {
        let latest: String?
    }

    struct AbilitySlot: Decodable, Sendable {
        let ability: APIRef
    }

    struct TypeSlot: Decodable, Sendable {
        let type: APIRef
    }

    struct MoveSlot: Decodable, Sendable {
        let move: APIRef
    }

    struct BaseStat: Decodable, Sendable {
        let baseStat: Int
        let stat: APIRef
    }

    let id: Int
    /// Raw API name (lowercase, e.g. "mr-mime"); capitalized when the
    /// `Pokemon` row is built.
    let name: String
    let weight: Int
    let height: Int
    let cries: Cries
    let sprites: Sprites
    let abilities: [AbilitySlot]
    let moves: [MoveSlot]
    let types: [TypeSlot]
    let stats: [BaseStat]
}

/// `/item/{id}` detail payload.
struct ItemDetailDTO: Decodable, Sendable {
    struct Sprites: Decodable, Sendable {
        let `default`: String?
    }

    struct EffectEntry: Decodable, Sendable {
        let shortEffect: String
        let language: APIRef
    }

    let id: Int
    let name: String
    let sprites: Sprites?
    let category: APIRef
    let effectEntries: [EffectEntry]

    /// English effect texts. PokeAPI ships one entry per language, and a
    /// SwiftData to-many relationship doesn't keep order, so only English is
    /// persisted. Falls back to every entry if an item has no English text.
    var englishEffects: [String] {
        let english = effectEntries.filter { $0.language.name == "en" }
        return (english.isEmpty ? effectEntries : english).map(\.shortEffect)
    }
}
