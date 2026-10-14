import Foundation
import PokeBattleKit

/// Wire protocol version. Bumped on any breaking change to `BattleMessage`
/// shape or to the per-event payload format. Exchanged in `.hello`; peers
/// reject mismatches (see `MultiplayerSetupViewModel`), so devices running
/// different app versions fail cleanly instead of misreading messages.
enum MultipeerProtocol {
    static let version: Int = 1
}

/// Pokemon + chosen moves sent by each side during the lobby handshake.
struct ChallengePayload: Codable, Sendable {
    let pokemon: PokemonSummary
    let moveNames: [String]

    init(pokemon: PokemonSummary, moveNames: [String]) {
        self.pokemon = pokemon
        self.moveNames = moveNames
    }
}

/// All messages exchanged between two peers across a multiplayer battle's
/// lifetime. A single Codable enum keeps the wire surface tight and the
/// receive switch exhaustive.
///
/// The host is authoritative: it runs the battle engine and the guest only
/// replays the resolved events, so both screens stay in sync without each
/// device simulating the turn.
///
/// Encoded by hand as a flat JSON object with a `"type"` discriminator
/// (e.g. `{"type":"moveCommitted","moveName":"tackle","turnNumber":3}`)
/// rather than Swift's synthesized enum coding, so the format is explicit
/// and stable. The `type` strings and `CodingKeys` are the wire format:
/// renaming either breaks compatibility with other installs and requires
/// bumping `MultipeerProtocol.version`.
enum BattleMessage: Codable, Sendable {
    /// First message both peers send after MC session connects. Establishes
    /// protocol version and declares each peer's role (the peer that
    /// accepted the invitation is the host).
    case hello(protocolVersion: Int, displayName: String, isHost: Bool)

    /// Host announces its loadout to the guest.
    case challengeProposed(ChallengePayload)
    /// Guest accepts and announces its own loadout.
    case challengeAccepted(ChallengePayload)
    /// Guest declines the proposed challenge.
    case challengeDeclined

    /// A peer has committed a move for turn `turnNumber`. Sent by both
    /// sides; host collects both, runs the engine, replies with `roundResolved`.
    case moveCommitted(moveName: String, turnNumber: Int)
    /// Host's resolved events for turn `turnNumber`. Guest applies + animates.
    case roundResolved(events: [Event], turnNumber: Int)
    /// Battle ended on host. Guest mirrors winner.
    case battleEnded(winner: Side?)

    /// Either peer requests a fresh battle with new loadouts.
    case rematch
    /// Either peer leaves the session cleanly (no error path).
    case disconnect

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, protocolVersion, displayName, isHost
        case payload, moveName, turnNumber, events, winner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hello":
            self = .hello(
                protocolVersion: try c.decode(Int.self, forKey: .protocolVersion),
                displayName: try c.decode(String.self, forKey: .displayName),
                isHost: try c.decode(Bool.self, forKey: .isHost)
            )
        case "challengeProposed":
            self = .challengeProposed(try c.decode(ChallengePayload.self, forKey: .payload))
        case "challengeAccepted":
            self = .challengeAccepted(try c.decode(ChallengePayload.self, forKey: .payload))
        case "challengeDeclined":
            self = .challengeDeclined
        case "moveCommitted":
            self = .moveCommitted(
                moveName: try c.decode(String.self, forKey: .moveName),
                turnNumber: try c.decode(Int.self, forKey: .turnNumber)
            )
        case "roundResolved":
            self = .roundResolved(
                events: try c.decode([Event].self, forKey: .events),
                turnNumber: try c.decode(Int.self, forKey: .turnNumber)
            )
        case "battleEnded":
            self = .battleEnded(winner: try c.decodeIfPresent(Side.self, forKey: .winner))
        case "rematch":
            self = .rematch
        case "disconnect":
            self = .disconnect
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: c,
                debugDescription: "Unknown BattleMessage type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let version, let name, let isHost):
            try c.encode("hello", forKey: .type)
            try c.encode(version, forKey: .protocolVersion)
            try c.encode(name, forKey: .displayName)
            try c.encode(isHost, forKey: .isHost)
        case .challengeProposed(let payload):
            try c.encode("challengeProposed", forKey: .type)
            try c.encode(payload, forKey: .payload)
        case .challengeAccepted(let payload):
            try c.encode("challengeAccepted", forKey: .type)
            try c.encode(payload, forKey: .payload)
        case .challengeDeclined:
            try c.encode("challengeDeclined", forKey: .type)
        case .moveCommitted(let name, let turn):
            try c.encode("moveCommitted", forKey: .type)
            try c.encode(name, forKey: .moveName)
            try c.encode(turn, forKey: .turnNumber)
        case .roundResolved(let events, let turn):
            try c.encode("roundResolved", forKey: .type)
            try c.encode(events, forKey: .events)
            try c.encode(turn, forKey: .turnNumber)
        case .battleEnded(let winner):
            try c.encode("battleEnded", forKey: .type)
            try c.encodeIfPresent(winner, forKey: .winner)
        case .rematch:
            try c.encode("rematch", forKey: .type)
        case .disconnect:
            try c.encode("disconnect", forKey: .type)
        }
    }
}
