import Foundation
import PokeBattleKit

/// Display-ready data for a single Pokemon, computed eagerly on init.
///
/// A value snapshot of the SwiftData `Pokemon`, so detail subviews read
/// precomputed strings instead of re-walking relationships on every body
/// evaluation. Conforms to PokeBattleKit's `PokemonData` so the same value
/// can seed a battle.
struct PokemonViewModel {
    let id: Int
    let name: String
    let frontSprite: String
    var isBookmarked: Bool

    let statLookup: [String: Int]
    let typeNames: [String]
    let types: String
    let abilities: String
    let moves: String

    private(set) var pokemon: Pokemon

    init(pokemon: Pokemon) {
        self.pokemon = pokemon
        self.id = pokemon.id
        self.name = pokemon.name.capitalized
        self.frontSprite = pokemon.sprite.front
        self.isBookmarked = pokemon.isBookmarked

        self.statLookup = Dictionary(
            uniqueKeysWithValues: pokemon.stats.map { ($0.stat.name, $0.baseStat) }
        )
        let rawTypeNames = pokemon.types.map { $0.type.name }
        self.typeNames = rawTypeNames
        self.types = pokemon.types.map { $0.type }.joinedCapitalizedNames
        self.abilities = pokemon.abilities.map { $0.ability }.joinedCapitalizedNames

        let capitalized = pokemon.moveNames.map { $0.capitalized }
        let displayed = Array(capitalized.prefix(16))
        let joined = displayed.joined(separator: ", ")
        self.moves = capitalized.count > displayed.count ? "\(joined)..." : joined
    }
}

extension PokemonViewModel {
    var backSprite: String? { pokemon.sprite.back }
    var height: String {
        Measurement(value: Double(pokemon.height) / 10.0, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
            .pixelFontSafe
    }
    var weight: String {
        Measurement(value: Double(pokemon.weight) / 10.0, unit: UnitMass.kilograms)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
            .pixelFontSafe
    }
    var latestCry: String? { pokemon.cries.latest }
    var stats: [Stat] { pokemon.stats }
    var habitat: String? { pokemon.habitat?.capitalized }
    var flavorText: String? { pokemon.flavorText?.pretty }
    var genus: String? { pokemon.genus?.pretty }
    /// Short generation label, e.g. "GEN IV".
    var generationLabel: String? {
        pokemon.generationName?
            .uppercased()
            .replacingOccurrences(of: "GENERATION-", with: "GEN ")
    }
    var genderRate: Int { pokemon.genderRate }
    /// Capture rate as a percentage string, e.g. "45%".
    var capturePercent: String {
        (Double(pokemon.captureRate) / 255.0).formatted(.pixelPercent())
    }
    var evolutionChainId: String? { pokemon.evolutionChainId }
    var baseStatTotal: Int { pokemon.stats.map(\.baseStat).reduce(0, +) }
    var isLegendary: Bool { pokemon.isLegendary }
    var isMythical: Bool { pokemon.isMythical }
}

extension PokemonViewModel: PokemonData {
    /// The raw weight, for weight-based moves (`weight` is the display text).
    var weightInHectograms: Int? { pokemon.weight }
}

extension PokemonViewModel: Hashable {
    static func == (lhs: PokemonViewModel, rhs: PokemonViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Anything with an API `name` (types, abilities), so one helper can turn a
/// list of them into a capitalized, comma-separated display string.
private protocol NameProvidable {
    var name: String { get }
}

// MARK: - Private
private extension Array where Element: NameProvidable {
    var joinedCapitalizedNames: String {
        map { $0.name.capitalized }.joined(separator: ", ")
    }
}

extension APIItem: NameProvidable {}
