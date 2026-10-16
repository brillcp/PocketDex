import Foundation
import PokeBattleKit

/// Wire protocol version for PokeBattleKit's `BattleMessage<PokemonSummary>`.
/// Bumped on any breaking change to the messages: PokeBattleKit's message
/// and `Event` formats and battle rules, or `PokemonSummary`. Exchanged in `.hello`; peers reject mismatches (see
/// `MultiplayerSetupViewModel`), so devices running different app versions
/// fail cleanly instead of misreading messages.
enum MultipeerProtocol {
    /// 2: level-50 stats, new events (flinched, failed, hitCount) and new
    /// move fields. 3: freeze (frozenSolid, thawed), situational move power,
    /// smaller loadouts, and Pokémon weight in `PokemonSummary`.
    static let version: Int = 3
}
