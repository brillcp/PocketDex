import PokeBattleKit

/// PokeBattleKit's move and type catalogue, behind a protocol so app code
/// reaches it through `AppContainer` instead of the package's globals.
///
/// The catalogue downloads once (then reads from PokeBattleKit's disk
/// cache), so `typeChart` is `nil` and `allMoves` empty until `load()` has
/// finished.
protocol BattleCatalog: Sendable {
    /// The type chart, or `nil` while the catalogue is still loading.
    var typeChart: TypeChart? { get }
    /// Every move in the catalogue (empty while loading).
    var allMoves: [Move] { get }
    /// The move with this API name (e.g. "thunderbolt"), if it's loaded.
    func move(named name: String) -> Move?
    /// Loads the catalogue, or retries after a failed load. Safe to call
    /// repeatedly and concurrently: later calls share or skip the load.
    func load() async throws
}

/// The live catalogue: PokeBattleKit's shared, lock-guarded store.
struct PokeBattleKitCatalog: BattleCatalog {
    var typeChart: TypeChart? { PokeBattleKit.loadedTypeChart }
    var allMoves: [Move] { PokeBattleKit.allMoves }

    func move(named name: String) -> Move? {
        PokeBattleKit.move(named: name)
    }

    func load() async throws {
        try await PokeBattleKit.initialize()
    }
}
