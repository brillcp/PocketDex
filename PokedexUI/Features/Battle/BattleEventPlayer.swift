import SwiftUI
import PokeBattleKit

/// The screen state a turn's events are played into. Both battle view
/// models conform, so `BattleEventPlayer` drives either one.
@MainActor
protocol BattleEventSink: AnyObject {
    var state: BattleState? { get set }
    var log: [BattleLogEntry] { get set }
    var winner: Side? { get set }
}

/// Plays the battle on screen, shared by single-player and multiplayer:
/// the entrance, then each resolved turn. For each event, add its log line, reduce it into the
/// displayed state, and await its animation. Stops at `.ended`, setting the
/// winner and playing the winner's cry.
@MainActor
struct BattleEventPlayer {
    /// How a played turn finished.
    enum Result {
        case continuing
        /// The battle ended; `winner` is the event's own (`nil` for a draw).
        case ended(winner: Side?)
    }

    /// The winner the screen shows: a draw (`nil`) is shown as a player win.
    nonisolated static func shownWinner(_ winner: Side?) -> Side {
        winner ?? .player
    }

    let formatter: BattleLogFormatter
    let animator: BattleAnimator
    let audioPlayer: AudioPlaying
    let playerCry: String?
    let opponentCry: String?

    /// The opening: the entrance animation, the `announcement` line (given
    /// the opponent's sprite color), then the opponent's cry.
    func playEntrance(into sink: some BattleEventSink, announcement: (Color?) -> AttributedString) async {
        await animator.playEntrance()
        sink.log.append(.regular(announcement(animator.opponentCues.color)))
        if let opponentCry {
            await audioPlayer.play(from: opponentCry)
        }
    }

    @discardableResult
    func play(_ events: [Event], into sink: some BattleEventSink) async -> Result {
        for event in events {
            let line = formatter.format(
                event,
                playerColor: animator.playerCues.color,
                opponentColor: animator.opponentCues.color
            )
            sink.log.append(.regular(line))
            if var snapshot = sink.state {
                BattleStateReducer.apply(event, to: &snapshot, animator: animator)
                sink.state = snapshot
            }
            await animator.play(event)
            try? await Task.sleep(for: .milliseconds(650))
            if case .ended(let w) = event {
                let shown = Self.shownWinner(w)
                sink.winner = shown
                await playCry(of: shown)
                return .ended(winner: w)
            }
        }
        return .continuing
    }
}

// MARK: - Private
private extension BattleEventPlayer {
    func playCry(of side: Side) async {
        guard let cry = side == .player ? playerCry : opponentCry else { return }
        try? await Task.sleep(for: .milliseconds(350))
        await audioPlayer.play(from: cry)
    }
}
