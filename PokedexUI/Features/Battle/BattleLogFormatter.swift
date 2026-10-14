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
            return AttributedString(
                localized: "\(nameAttr(side)) used \(bold(moveName))",
                comment: "Battle log line. The first variable is the attacking Pokémon, the second is the move name."
            )
        case .missed(let side):
            return AttributedString(
                localized: "\(nameAttr(side))'s attack missed",
                comment: "Battle log line. The variable is the Pokémon whose attack missed."
            )
        case .damaged(let side, let amount, let effectiveness, let crit):
            if effectiveness == 0 {
                return AttributedString(
                    localized: "It had no effect on \(nameAttr(side))",
                    comment: "Battle log line for an immune target. The variable is the defending Pokémon."
                )
            }
            let damage = colored(
                AttributedString(localized: "\(String(amount)) dmg", comment: "Damage amount in the battle log. The variable is HP lost."),
                Color.pokedexRed
            )
            var line = AttributedString(
                localized: "\(nameAttr(side)) took \(damage)",
                comment: "Battle log line. The first variable is the damaged Pokémon, the second is the damage amount."
            )
            if crit {
                line += colored(AttributedString(localized: " (critical hit)", comment: "Battle log suffix for a critical hit."), .yellow)
            }
            if effectiveness >= 2 {
                line += colored(AttributedString(localized: " (super effective)", comment: "Battle log suffix for a super effective hit."), .green)
            } else if effectiveness < 1 {
                line += colored(AttributedString(localized: " (not very effective)", comment: "Battle log suffix for a not very effective hit."), .gray)
            }
            return line
        case .statusApplied(let side, let status):
            return AttributedString(
                localized: "\(nameAttr(side)) was inflicted with \(colored(status.displayName, statusColor(status)))",
                comment: "Battle log line. The first variable is the Pokémon, the second is the status condition."
            )
        case .statusTick(let side, let status, let amount):
            return AttributedString(
                localized: "\(nameAttr(side)) hurt by \(colored(status.displayName, statusColor(status))) (\(colored("-\(amount)", Color.pokedexRed)))",
                comment: "Battle log line. The first variable is the Pokémon, the second is the status condition, the third is HP lost."
            )
        case .statChanged(let side, let stat, let delta):
            let pretty = stat.replacingOccurrences(of: "-", with: " ").capitalized
            let tint: Color = delta > 0 ? .green : Color.pokedexRed
            let sharp = abs(delta) >= 2
            if delta > 0 {
                let rose = colored(AttributedString(localized: "rose", comment: "Battle log verb for a raised stat."), tint)
                return sharp
                    ? AttributedString(localized: "\(nameAttr(side))'s \(pretty) sharply \(rose)", comment: "Battle log line for a stat raised by two or more stages. The first variable is the Pokémon, the second is the stat, the third is the word \"rose\".")
                    : AttributedString(localized: "\(nameAttr(side))'s \(pretty) \(rose)", comment: "Battle log line for a raised stat. The first variable is the Pokémon, the second is the stat, the third is the word \"rose\".")
            }
            let fell = colored(AttributedString(localized: "fell", comment: "Battle log verb for a lowered stat."), tint)
            return sharp
                ? AttributedString(localized: "\(nameAttr(side))'s \(pretty) sharply \(fell)", comment: "Battle log line for a stat lowered by two or more stages. The first variable is the Pokémon, the second is the stat, the third is the word \"fell\".")
                : AttributedString(localized: "\(nameAttr(side))'s \(pretty) \(fell)", comment: "Battle log line for a lowered stat. The first variable is the Pokémon, the second is the stat, the third is the word \"fell\".")
        case .healed(let side, let amount):
            let hp = colored(AttributedString(localized: "\(String(amount)) HP", comment: "Healed amount in the battle log. The variable is HP restored."), .green)
            return AttributedString(
                localized: "\(nameAttr(side)) restored \(hp)",
                comment: "Battle log line. The first variable is the Pokémon, the second is the HP restored."
            )
        case .recoil(let side, let amount):
            let recoil = colored(AttributedString(localized: "\(String(amount)) recoil", comment: "Recoil amount in the battle log. The variable is HP lost."), Color.pokedexRed)
            return AttributedString(
                localized: "\(nameAttr(side)) took \(recoil) damage",
                comment: "Battle log line. The first variable is the Pokémon, the second is the recoil amount."
            )
        case .wokeUp(let side):
            return AttributedString(
                localized: "\(nameAttr(side)) woke up",
                comment: "Battle log line. The variable is the Pokémon that woke up."
            )
        case .fastAsleep(let side):
            let asleep = colored(AttributedString(localized: "fast asleep", comment: "Battle log status phrase for a sleeping Pokémon."), statusColor(.sleep))
            return AttributedString(
                localized: "\(nameAttr(side)) is \(asleep)",
                comment: "Battle log line. The first variable is the Pokémon, the second is the phrase \"fast asleep\"."
            )
        case .recharging(let side):
            let recharge = colored(AttributedString(localized: "recharge", comment: "Battle log verb for a Pokémon that must skip a turn."), .gray)
            return AttributedString(
                localized: "\(nameAttr(side)) must \(recharge)",
                comment: "Battle log line. The first variable is the Pokémon, the second is the word \"recharge\"."
            )
        case .fullyParalyzed(let side):
            let paralyzed = colored(AttributedString(localized: "fully paralyzed", comment: "Battle log status phrase for a paralyzed Pokémon."), statusColor(.paralysis))
            return AttributedString(
                localized: "\(nameAttr(side)) is \(paralyzed)",
                comment: "Battle log line. The first variable is the Pokémon, the second is the phrase \"fully paralyzed\"."
            )
        case .lostFocus(let side):
            let focus = colored(AttributedString(localized: "focus", comment: "Battle log noun for a Pokémon losing concentration."), .gray)
            return AttributedString(
                localized: "\(nameAttr(side)) lost its \(focus)",
                comment: "Battle log line. The first variable is the Pokémon, the second is the word \"focus\"."
            )
        case .fainted(let side):
            return tinted(
                AttributedString(localized: "\(nameAttr(side)) fainted!", comment: "Battle log line. The variable is the Pokémon that fainted."),
                Color.pokedexRed
            )
        case .ended(let w):
            guard let winner = w else {
                return AttributedString(localized: "It's a draw.", comment: "Battle log line when neither side wins.")
            }
            return tinted(
                AttributedString(localized: "\(nameAttr(winner)) wins!", comment: "Battle log line. The variable is the winning Pokémon."),
                .green
            )
        }
    }

    func wildAppeared(opponentColor: Color?) -> AttributedString {
        var attr = nameAttr(opponentName, color: opponentColor)
        attr.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(
            localized: "A wild \(attr) appeared!",
            comment: "Battle log line when the battle starts. The variable is the opponent Pokémon."
        )
    }

    /// Multiplayer-flavored entrance line shown when a peer's pokemon arrives.
    func opponentReady(opponentColor: Color?) -> AttributedString {
        var attr = nameAttr(opponentName, color: opponentColor)
        attr.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(
            localized: "\(attr) is ready to battle!",
            comment: "Multiplayer battle log line. The variable is the opponent's Pokémon."
        )
    }

    /// Placeholder line shown after the local player commits a move while
    /// the remote peer's commit is still in flight.
    func waitingForOpponent() -> AttributedString {
        var str = AttributedString(localized: "Waiting for opponent", comment: "Multiplayer battle log line while the other player picks a move.")
        str.foregroundColor = .gray
        return str
    }

    /// Prompt shown when the peer has already committed and is waiting on us.
    func chooseMove() -> AttributedString {
        var str = AttributedString(localized: "Pick a move", comment: "Multiplayer battle log prompt asking the player to choose a move.")
        str.foregroundColor = .yellow
        return str
    }
}

// MARK: - Private
private extension BattleLogFormatter {
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

    /// Colors every run of a localized line that doesn't already carry a
    /// color (the interpolated name keeps its own tint).
    func tinted(_ text: AttributedString, _ color: Color) -> AttributedString {
        var str = text
        for run in str.runs where run.foregroundColor == nil {
            str[run.range].foregroundColor = color
        }
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
