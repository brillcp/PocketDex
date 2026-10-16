import PokeBattleKit

extension PokeBattleKit {
    /// The type chart, or `nil` while `initialize()` hasn't finished (first
    /// launch), for display code that shouldn't trap like `typeChart` does.
    ///
    /// PokeBattleKit 0.1.10+ ships this as `loadedTypeChart`; switch to it
    /// once the app depends on that release.
    static var typeChartIfLoaded: TypeChart? {
        isInitialized ? typeChart : nil
    }
}
