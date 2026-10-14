/// Sendable decoding payloads for PokeAPI responses. These are what cross
/// from the network into `PokedexStore`; the `@Model` classes are built
/// from them on the store's background context.

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
        let front: String
        let back: String?

        private enum CodingKeys: String, CodingKey {
            case front = "front_default"
            case back = "back_default"
        }
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

        private enum CodingKeys: String, CodingKey {
            case stat
            case baseStat = "base_stat"
        }
    }

    let id: Int
    let name: String
    let weight: Int
    let height: Int
    let cries: Cries
    let sprites: Sprites
    let abilities: [AbilitySlot]
    let moves: [MoveSlot]
    let types: [TypeSlot]
    let stats: [BaseStat]

    private enum CodingKeys: String, CodingKey {
        case id, name, weight, height, cries, sprites, abilities, moves, types, stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name).capitalized
        weight = try container.decode(Int.self, forKey: .weight)
        height = try container.decode(Int.self, forKey: .height)
        cries = try container.decode(Cries.self, forKey: .cries)
        sprites = try container.decode(Sprites.self, forKey: .sprites)
        abilities = try container.decode([AbilitySlot].self, forKey: .abilities)
        moves = try container.decode([MoveSlot].self, forKey: .moves)
        types = try container.decode([TypeSlot].self, forKey: .types)
        stats = try container.decode([BaseStat].self, forKey: .stats)
    }
}

/// `/item/{id}` detail payload.
struct ItemDetailDTO: Decodable, Sendable {
    struct Sprites: Decodable, Sendable {
        let `default`: String?
    }

    struct EffectEntry: Decodable, Sendable {
        let shortEffect: String
        let language: APIRef

        private enum CodingKeys: String, CodingKey {
            case shortEffect = "short_effect"
            case language
        }
    }

    let id: Int
    let name: String
    let sprites: Sprites?
    let category: APIRef
    let effectEntries: [EffectEntry]

    private enum CodingKeys: String, CodingKey {
        case id, name, sprites, category
        case effectEntries = "effect_entries"
    }

    /// English effect texts. PokeAPI ships one entry per language, and a
    /// SwiftData to-many relationship doesn't keep order, so only English is
    /// persisted. Falls back to every entry if an item has no English text.
    var englishEffects: [String] {
        let english = effectEntries.filter { $0.language.name == "en" }
        return (english.isEmpty ? effectEntries : english).map(\.shortEffect)
    }
}
