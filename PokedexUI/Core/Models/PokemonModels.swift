import SwiftData

/// Full hydrated pokemon record cached on first fetch.
///
/// Persistence-only: network payloads decode into `PokemonDTO` and
/// `PokedexStore` builds these rows on its background context, so model
/// instances never cross actors.
@Model
final class Pokemon {
    @Attribute(.unique) var id: Int
    var name: String
    var weight: Int
    var height: Int
    var isBookmarked: Bool = false
    var cries: Cries
    var sprite: Sprite
    var abilities: [Ability]
    var moveNames: [String]
    var types: [Type]
    var stats: [Stat]
    var habitat: String?
    var flavorText: String?
    var genus: String? = nil
    var generationName: String? = nil
    var genderRate: Int = -1
    var captureRate: Int = 0
    var baseHappiness: Int = 0
    var evolutionChainId: String? = nil
    var isLegendary: Bool = false
    var isMythical: Bool = false

    init(
        id: Int,
        name: String,
        weight: Int,
        height: Int,
        cries: Cries,
        sprite: Sprite,
        abilities: [Ability],
        moveNames: [String],
        types: [Type],
        stats: [Stat],
        habitat: String? = nil,
        flavorText: String? = nil,
        genus: String? = nil,
        generationName: String? = nil,
        genderRate: Int = -1,
        captureRate: Int = 0,
        baseHappiness: Int = 0,
        evolutionChainId: String? = nil,
        isLegendary: Bool = false,
        isMythical: Bool = false
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.height = height
        self.cries = cries
        self.sprite = sprite
        self.abilities = abilities
        self.moveNames = moveNames
        self.types = types
        self.stats = stats
        self.habitat = habitat
        self.flavorText = flavorText
        self.genus = genus
        self.generationName = generationName
        self.genderRate = genderRate
        self.captureRate = captureRate
        self.baseHappiness = baseHappiness
        self.evolutionChainId = evolutionChainId
        self.isLegendary = isLegendary
        self.isMythical = isMythical
    }
}

extension Pokemon {
    /// Build a persistence row from a decoded detail payload plus its
    /// (optional) species payload.
    convenience init(dto: PokemonDTO, species: PokemonSpecies?) {
        self.init(
            id: dto.id,
            name: dto.name,
            weight: dto.weight,
            height: dto.height,
            cries: Cries(latest: dto.cries.latest),
            sprite: Sprite(front: dto.sprites.front, back: dto.sprites.back),
            abilities: dto.abilities.map { Ability(ability: APIItem($0.ability)) },
            moveNames: dto.moves.map(\.move.name),
            types: dto.types.map { Type(type: APIItem($0.type)) },
            stats: dto.stats.map { Stat(baseStat: $0.baseStat, stat: APIItem($0.stat)) },
            habitat: species?.habitat?.name,
            flavorText: species?.englishFlavorText,
            genus: species?.englishGenus,
            generationName: species?.generation?.name,
            genderRate: species?.genderRate ?? -1,
            captureRate: species?.captureRate ?? 0,
            baseHappiness: species?.baseHappiness ?? 0,
            evolutionChainId: species?.evolutionChain?.id,
            isLegendary: species?.isLegendary ?? false,
            isMythical: species?.isMythical ?? false
        )
    }
}

extension Pokemon {
    var frontSprite: String { sprite.front }
    var backSprite: String? { sprite.back }

    /// Normalized haystack for full-text search across name, types,
    /// genus, habitat, legendary/mythical status, and abilities.
    static func searchHaystack(for pokemon: Pokemon) -> String {
        var parts: [String] = [pokemon.name.normalize]
        parts.append(contentsOf: pokemon.types.map(\.type.name.normalize))
        if let genus = pokemon.genus { parts.append(genus.normalize) }
        if let habitat = pokemon.habitat { parts.append(habitat.normalize) }
        if pokemon.isLegendary { parts.append("legendary") }
        if pokemon.isMythical { parts.append("mythical") }
        parts.append(contentsOf: pokemon.abilities.map(\.ability.name.normalize))
        return parts.joined(separator: " ")
    }
}

extension Pokemon {
    static var pikachu: Pokemon {
        Pokemon(
            id: 25,
            name: "Pikachu",
            weight: 60,
            height: 4,
            cries: Cries(latest: nil),
            sprite: Sprite(
                front: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/3.png",
                back: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/6.png"
            ),
            abilities: [
                Ability(ability: APIItem(name: "static", url: "")),
                Ability(ability: APIItem(name: "lightning-rod", url: ""))
            ],
            moveNames: ["mega-punch", "pay-day", "thunder-punch", "slam", "thunderbolt"],
            types: [
                Type(type: APIItem(name: "electric", url: ""))
            ],
            stats: [
                Stat(baseStat: 35, stat: APIItem(name: "hp", url: "")),
                Stat(baseStat: 55, stat: APIItem(name: "attack", url: "")),
                Stat(baseStat: 40, stat: APIItem(name: "defense", url: "")),
                Stat(baseStat: 50, stat: APIItem(name: "special-attack", url: "")),
                Stat(baseStat: 50, stat: APIItem(name: "special-defense", url: "")),
                Stat(baseStat: 90, stat: APIItem(name: "speed", url: ""))
            ],
            habitat: "Forest",
            flavorText: "This Pokemon is electric. This Pokemon is electric. This Pokemon is electric. This Pokemon is electric. ",
            genderRate: 5,
            evolutionChainId: "10"
        )
    }
}

// MARK: - SwiftData models

/// Ability slot on a `Pokemon`. Wraps an `APIItem` reference (name + URL)
/// to the canonical ability record on PokeAPI.
@Model
final class Ability {
    var ability: APIItem

    @Relationship(inverse: \Pokemon.abilities)
    var pokemon: Pokemon?

    init(ability: APIItem) {
        self.ability = ability
    }
}

/// Default front + optional back sprite URLs.
@Model
final class Sprite {
    var front: String
    var back: String?

    init(front: String, back: String?) {
        self.front = front
        self.back = back
    }
}

/// Audio cry URLs. PokeAPI exposes both a legacy and a latest variant;
/// PokedexUI plays `latest` if present.
@Model
final class Cries {
    var latest: String?

    init(latest: String?) {
        self.latest = latest
    }
}

/// One of a pokemon's 1 or 2 elemental types. Wraps an `APIItem` so the type
/// name aligns with the `TypeChart` keys used by the damage formula.
@Model
final class Type {
    var type: APIItem

    @Relationship(inverse: \Pokemon.types)
    var pokemon: Pokemon?

    init(type: APIItem) {
        self.type = type
    }

    var name: String {
        type.name
    }
}

/// One of the six base stats (HP, attack, defense, sp.atk, sp.def, speed)
/// with its raw integer value. Used by the battle engine + stats UI on the
/// detail view.
@Model
final class Stat {
    var baseStat: Int
    var stat: APIItem

    @Relationship(inverse: \Pokemon.stats)
    var pokemon: Pokemon?

    init(baseStat: Int, stat: APIItem) {
        self.baseStat = baseStat
        self.stat = stat
    }
}
