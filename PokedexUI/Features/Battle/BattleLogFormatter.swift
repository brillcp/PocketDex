import SwiftUI
import PokeBattleKit

/// A single row in the battle log with a stable identity.
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
            return nameAttr(side) + plain(" used ") + bold(moveName)
        case .missed(let side):
            return nameAttr(side) + plain("'s attack missed")
        case .damaged(let side, let amount, let effectiveness, let crit):
            if effectiveness == 0 {
                return plain("It had no effect on ") + nameAttr(side)
            }
            var line = nameAttr(side) + plain(" took ") + colored("\(amount) dmg", Color.pokedexRed)
            if crit {
                line += colored(" (critical hit)", .yellow)
            }
            if effectiveness >= 2 {
                line += colored(" (super effective)", .green)
            } else if effectiveness < 1 {
                line += colored(" (not very effective)", .gray)
            }
            return line
        case .statusApplied(let side, let status):
            return nameAttr(side) + plain(" was inflicted with ") + colored(status.displayName, statusColor(status))
        case .statusTick(let side, let status, let amount):
            return nameAttr(side) + plain(" hurt by ") + colored(status.displayName, statusColor(status))
                + plain(" (") + colored("-\(amount)", Color.pokedexRed) + plain(")")
        case .statChanged(let side, let stat, let delta):
            let pretty = stat.replacingOccurrences(of: "-", with: " ").capitalized
            let tint: Color = delta > 0 ? .green : Color.pokedexRed
            let sharp = abs(delta) >= 2 ? "sharply " : ""
            let verb = delta > 0 ? "rose" : "fell"
            return nameAttr(side) + plain("'s \(pretty) \(sharp)") + colored(verb, tint)
        case .healed(let side, let amount):
            return nameAttr(side) + plain(" restored ") + colored("\(amount) HP", .green)
        case .recoil(let side, let amount):
            return nameAttr(side) + plain(" took ") + colored("\(amount) recoil", Color.pokedexRed) + plain(" damage")
        case .wokeUp(let side):
            return nameAttr(side) + plain(" woke up")
        case .fastAsleep(let side):
            return nameAttr(side) + plain(" is ") + colored("fast asleep", statusColor(.sleep))
        case .recharging(let side):
            return nameAttr(side) + plain(" must ") + colored("recharge", .gray)
        case .fullyParalyzed(let side):
            return nameAttr(side) + plain(" is ") + colored("fully paralyzed", statusColor(.paralysis))
        case .lostFocus(let side):
            return nameAttr(side) + plain(" lost its ") + colored("focus", .gray)
        case .fainted(let side):
            return nameAttr(side) + colored(" fainted!", Color.pokedexRed)
        case .ended(let w):
            guard let winner = w else {
                return plain("It's a draw.")
            }
            return nameAttr(winner) + colored(" wins!", .green)
        }
    }

    func wildAppeared(opponentColor: Color?) -> AttributedString {
        var attr = nameAttr(opponentName, color: opponentColor)
        attr.inlinePresentationIntent = .stronglyEmphasized
        return plain("A wild ") + attr + plain(" appeared!")
    }

    /// Multiplayer-flavored entrance line shown when a peer's pokemon arrives.
    func opponentReady(opponentColor: Color?) -> AttributedString {
        var attr = nameAttr(opponentName, color: opponentColor)
        attr.inlinePresentationIntent = .stronglyEmphasized
        return attr + plain(" is ready to battle!")
    }

    /// Placeholder line shown after the local player commits a move while
    /// the remote peer's commit is still in flight.
    func waitingForOpponent() -> AttributedString {
        colored("Waiting for opponent", .gray)
    }

    /// Prompt shown when the peer has already committed and is waiting on us.
    func chooseMove() -> AttributedString {
        colored("Pick a move", .yellow)
    }
}

// MARK: - Private
private extension BattleLogFormatter {
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
        }
    }
}
