import SwiftUI
import PokeBattleKit

/// A single row in the battle log with a stable identity.
///
/// `placeholder` ("...") and `prompt` rows are transient: view models remove
/// them by `kind` once the turn resolves, without touching real log lines.
struct BattleLogEntry: Identifiable, Equatable {
    enum Kind { case regular, placeholder, prompt }
    let id = UUID()
    let attributed: AttributedString
    let kind: Kind

    static func regular(_ attributed: AttributedString) -> BattleLogEntry {
        BattleLogEntry(attributed: attributed, kind: .regular)
    }
    static func prompt(_ attributed: AttributedString) -> BattleLogEntry {
        BattleLogEntry(attributed: attributed, kind: .prompt)
    }
    static var placeholder: BattleLogEntry {
        var str = AttributedString("...")
        str.foregroundColor = .gray
        return BattleLogEntry(attributed: str, kind: .placeholder)
    }
}

/// Formats `Event` values into styled `AttributedString` for the log feed.
///
/// Builds lines once when an event arrives, so the feed renders
/// pre-styled text instead of re-deriving colors per frame. Names take each
/// Pokémon's sprite color (passed in, since colors resolve asynchronously
/// after the formatter is created).
struct BattleLogFormatter {
    let playerName:   String
    let opponentName: String

    func format(
        _ event: Event,
        playerColor: Color?,
        opponentColor: Color?
    ) -> AttributedString {
        let nameAttr = { (side: Side) -> AttributedString in
            let name = side == .player ? self.playerName : self.opponentName
            let color = side == .player ? playerColor : opponentColor
            return self.nameAttr(name, color: color)
        }
        switch event {
        case .used(let side, let moveName):
            return line("battleLog.used", nameAttr(side), bold(moveName))
        case .missed(let side):
            return line("battleLog.missed", nameAttr(side))
        case .damaged(let side, let amount, let effectiveness, let crit):
            if effectiveness == 0 {
                return line("battleLog.noEffect", nameAttr(side))
            }
            var result = line("battleLog.damaged", nameAttr(side), colored(Localized("battleLog.damaged.amount", amount), Color.pokedexRed))
            if crit {
                result += colored(Localized("battleLog.criticalHit"), .yellow)
            }
            if effectiveness >= 2 {
                result += colored(Localized("battleLog.superEffective"), .green)
            } else if effectiveness < 1 {
                result += colored(Localized("battleLog.notVeryEffective"), .gray)
            }
            return result
        case .statusApplied(let side, let status):
            return line("battleLog.statusApplied", nameAttr(side), colored(status.displayName, statusColor(status)))
        case .statusTick(let side, let status, let amount):
            return line(
                "battleLog.statusTick",
                nameAttr(side),
                colored(status.displayName, statusColor(status)),
                colored("-\(amount)", Color.pokedexRed)
            )
        case .statChanged(let side, let stat, let delta):
            let pretty = stat.replacingOccurrences(of: "-", with: " ").capitalized
            let tint: Color = delta > 0 ? .green : Color.pokedexRed
            let change = switch (delta > 0, abs(delta) >= 2) {
            case (true, true): Localized("battleLog.stat.roseSharply")
            case (true, false): Localized("battleLog.stat.rose")
            case (false, true): Localized("battleLog.stat.fellSharply")
            case (false, false): Localized("battleLog.stat.fell")
            }
            return line("battleLog.statChanged", nameAttr(side), plain(pretty), colored(change, tint))
        case .healed(let side, let amount):
            return line("battleLog.healed", nameAttr(side), colored(Localized("battleLog.healed.amount", amount), .green))
        case .recoil(let side, let amount):
            return line("battleLog.recoil", nameAttr(side), colored(Localized("battleLog.recoil.amount", amount), Color.pokedexRed))
        case .wokeUp(let side):
            return line("battleLog.wokeUp", nameAttr(side))
        case .fastAsleep(let side):
            return line("battleLog.condition", nameAttr(side), colored(Localized("battleLog.condition.fastAsleep"), statusColor(.sleep)))
        case .recharging(let side):
            return line("battleLog.recharging", nameAttr(side), colored(Localized("battleLog.recharging.highlight"), .gray))
        case .frozenSolid(let side):
            return line("battleLog.condition", nameAttr(side), colored(Localized("battleLog.condition.frozenSolid"), statusColor(.freeze)))
        case .thawed(let side):
            return line("battleLog.thawed", nameAttr(side), colored(Localized("battleLog.thawed.highlight"), statusColor(.freeze)))
        case .fullyParalyzed(let side):
            return line("battleLog.condition", nameAttr(side), colored(Localized("battleLog.condition.fullyParalyzed"), statusColor(.paralysis)))
        case .lostFocus(let side):
            return line("battleLog.lostFocus", nameAttr(side), colored(Localized("battleLog.lostFocus.highlight"), .gray))
        case .flinched(let side):
            return line("battleLog.flinched", nameAttr(side), colored(Localized("battleLog.flinched.highlight"), .gray))
        case .failed:
            return line("battleLog.failed", colored(Localized("battleLog.failed.highlight"), .gray))
        case .hitCount(_, let count):
            return line("battleLog.hitCount", bold(Localized("battleLog.hitCount.times", count)))
        case .fainted(let side):
            return line("battleLog.fainted", nameAttr(side), colored(Localized("battleLog.fainted.highlight"), Color.pokedexRed))
        case .ended(let w):
            guard let winner = w else {
                return line("battleLog.draw")
            }
            return line("battleLog.wins", nameAttr(winner), colored(Localized("battleLog.wins.highlight"), .green))
        }
    }

    func wildAppeared(opponentColor: Color?) -> AttributedString {
        var attr = nameAttr(opponentName, color: opponentColor)
        attr.inlinePresentationIntent = .stronglyEmphasized
        return line("battleLog.wildAppeared", attr)
    }

    /// Multiplayer-flavored entrance line shown when a peer's pokemon arrives.
    func opponentReady(opponentColor: Color?) -> AttributedString {
        var attr = nameAttr(opponentName, color: opponentColor)
        attr.inlinePresentationIntent = .stronglyEmphasized
        return line("battleLog.opponentReady", attr)
    }

    /// Placeholder line shown after the local player commits a move while
    /// the remote peer's commit is still in flight.
    func waitingForOpponent() -> AttributedString {
        colored(Localized("battleLog.waitingForOpponent"), .gray)
    }

    /// Prompt shown when the peer has already committed and is waiting on us.
    func chooseMove() -> AttributedString {
        colored(Localized("battleLog.pickMove"), .yellow)
    }
}

// MARK: - Private
private extension BattleLogFormatter {
    /// One localized sentence with its styled parts filled in.
    func line(_ key: String, _ parts: AttributedString...) -> AttributedString {
        LocalizedAttributed(key, parts: parts)
    }

    func plain(_ text: String) -> AttributedString {
        AttributedString(text)
    }

    func nameAttr(_ name: String, color: Color?) -> AttributedString {
        var str = AttributedString(name)
        str.foregroundColor = legibleColor(color ?? .white)
        return str
    }

    func bold(_ text: String) -> AttributedString {
        var str = AttributedString(text)
        str.inlinePresentationIntent = .stronglyEmphasized
        return str
    }

    func colored(_ text: String, _ color: Color) -> AttributedString {
        colored(AttributedString(text), color)
    }

    func colored(_ text: AttributedString, _ color: Color) -> AttributedString {
        var str = text
        str.foregroundColor = color
        return str
    }

    /// Falls back to white for sprite colors too dark to read on the
    /// dark battle background (relative luminance below ~0.32).
    func legibleColor(_ color: Color) -> Color {
        let resolved = color.resolve(in: .init())
        let luminance = 0.2126 * Double(resolved.red) + 0.7152 * Double(resolved.green) + 0.0722 * Double(resolved.blue)
        return luminance < 0.32 ? .white : color
    }

    func statusColor(_ status: Status) -> Color {
        switch status {
        case .none: .white
        case .paralysis: .yellow
        case .burn: .orange
        case .poison: .purple
        case .sleep: .gray
        case .freeze: .cyan
        }
    }
}
