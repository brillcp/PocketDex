import Foundation
import PokeBattleKit

/// Codable, lightweight Pokemon DTO exchanged between peers during multiplayer
/// setup. Carries everything `Combatant` needs to build a battler plus a cry
/// URL for entrance audio. Move names are sent alongside in `BattleMessage`,
/// not embedded here.
struct PokemonSummary: Codable, Hashable, Sendable, PokemonData {
    let id: Int
    let name: String
    let frontSprite: String
    let backSprite: String?
    let typeNames: [String]
    let statLookup: [String: Int]
    let cryURL: String?

    init(
        id: Int,
        name: String,
        frontSprite: String,
        backSprite: String?,
        typeNames: [String],
        statLookup: [String: Int],
        cryURL: String?
    ) {
        self.id = id
        self.name = name
        self.frontSprite = frontSprite
        self.backSprite = backSprite
        self.typeNames = typeNames
        self.statLookup = statLookup
        self.cryURL = cryURL
    }
}

extension PokemonSummary {
    /// Project a hydrated `Pokemon` (SwiftData model) to a wire DTO. Call it
    /// on the actor that owns the model's context; the resulting value is
    /// Sendable and safe to hand to `MultipeerService`.
    init(pokemon: Pokemon) {
        self.id = pokemon.id
        self.name = pokemon.name
        self.frontSprite = pokemon.sprite.front
        self.backSprite = pokemon.sprite.back
        self.typeNames = pokemon.types.map { $0.type.name }
        self.statLookup = Dictionary(
            uniqueKeysWithValues: pokemon.stats.map { ($0.stat.name, $0.baseStat) }
        )
        self.cryURL = pokemon.cries.latest
    }
}
