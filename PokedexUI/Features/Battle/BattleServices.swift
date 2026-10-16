import PokeBattleKit

/// What a battle screen needs, and nothing more: cries, sprite colors, the
/// move and type catalogue, and the battle rules. Both battle view models
/// (AI and multiplayer) take this instead of the whole `AppContainer`.
struct BattleServices: Sendable {
    let audioPlayer: AudioPlaying
    let spriteLoader: SpriteLoading
    let imageColorAnalyzer: ImageColorAnalyzing
    let catalog: any BattleCatalogReading
    /// Level and battle length; both sides (and both peers) build their
    /// combatants with these.
    let rules: BattleRules
}

extension AppContainer {
    /// The battle-screen slice of the container.
    var battleServices: BattleServices {
        BattleServices(
            audioPlayer: audioPlayer,
            spriteLoader: spriteLoader,
            imageColorAnalyzer: imageColorAnalyzer,
            catalog: battleCatalog,
            rules: battleRules
        )
    }
}
