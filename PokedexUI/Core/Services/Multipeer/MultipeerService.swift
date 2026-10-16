import Foundation
// `@preconcurrency`: MultipeerConnectivity predates Swift concurrency and
// its types (`MCPeerID`, `MCSession`, …) aren't annotated `Sendable`. This
// downgrades the resulting diagnostics for values (like peer IDs) that are
// handed from MC's delegate queue to the main actor.
@preconcurrency import MultipeerConnectivity
import PokeBattleKit
import SwiftUI

/// Lightweight invitation handle for SwiftUI alert presentation.
struct PendingInvitation: Identifiable, Equatable {
    let id = UUID()
    let peerName: String
}

/// A nearby device, as the rest of the app sees it. Opaque: the
/// MultipeerConnectivity peer stays inside `MultipeerService`, so features
/// never depend on the framework.
struct PeerHandle: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
}

/// Typed events emitted by MultipeerConnectivity delegate callbacks.
/// Consumed by view models via the `events()` AsyncStream.
enum MultipeerEvent {
    case peerFound(PeerHandle)
    case peerLost(PeerHandle)
    case peerConnecting(PeerHandle)
    case peerConnected(PeerHandle)
    case peerDisconnected(PeerHandle)
    case invitationReceived(peerName: String)
    case advertisingFailed(Error)
    case browsingFailed(Error)
    case message(BattleMessage<PokemonSummary>)
}

/// Finding a nearby device and setting up the connection: discovery and
/// invitations. Only the lobby needs this.
@MainActor
protocol PeerDiscovering: AnyObject, Sendable {
    func startDiscovery()
    func stopDiscovery()
    /// Invite a discovered peer. The inviter becomes the guest.
    func invite(_ peer: PeerHandle)
    /// Accept the pending invitation. The accepter becomes the host.
    func acceptInvitation()
    func declineInvitation()
}

/// The connection itself: this device's role, its events, and a typed
/// message channel. The handshake and the battle only need this.
@MainActor
protocol PeerMessaging: AnyObject, Sendable {
    /// This device's role once connected (`nil` before then). Both devices
    /// advertise and browse at once, so the invitation decides it: the
    /// device that accepts an invite hosts (it runs the battle engine), the
    /// one that sent it is the guest.
    var role: PeerBattle.Role? { get }
    /// A new stream of every future event; each caller gets its own.
    func events() -> AsyncStream<MultipeerEvent>
    /// Send a message to the connected peer, in order and reliably.
    func send(_ message: BattleMessage<PokemonSummary>)
    /// Tell the peer we're leaving, then tear down the session.
    func disconnect()
}

/// Local peer-to-peer connection for multiplayer battles. View models
/// depend on these protocols, not on MultipeerConnectivity.
typealias MultipeerServicing = PeerDiscovering & PeerMessaging

/// Process-wide MultipeerConnectivity wrapper. Owns the `MCSession`,
/// advertiser, and browser; emits typed `MultipeerEvent`s via AsyncStream
/// for consumption by view models.
///
/// Isolation: the class is `@MainActor` so its state and the view models
/// that observe it live on one actor. MultipeerConnectivity calls its
/// delegates on a private queue, so every delegate method is `nonisolated`
/// and forwards to the main actor through `onMain` before touching state.
@MainActor
@Observable
final class MultipeerService: NSObject {
    private static let serviceType = "pokedex-vs"

    private var subscribers: [UUID: AsyncStream<MultipeerEvent>.Continuation] = [:]
    @ObservationIgnored private var connection: (peerID: MCPeerID, session: MCSession)?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitationHandler: ((Bool) -> Void)?
    /// The opaque handle handed out for each MultipeerConnectivity peer, and
    /// the peer behind each handle, so events and invites map both ways.
    @ObservationIgnored private var handles: [MCPeerID: PeerHandle] = [:]
    @ObservationIgnored private var peers: [UUID: MCPeerID] = [:]

    private(set) var role: PeerBattle.Role?

    /// Nonisolated so `AppContainer.live` (and the `\.container`
    /// environment default) can be built without the main actor. The peer
    /// and session are created on first use instead, on the main actor,
    /// because the display name comes from `UIDevice`.
    nonisolated override init() {
        super.init()
    }

    private var myPeerID: MCPeerID { resolvedConnection().peerID }
    private var session: MCSession { resolvedConnection().session }

    /// Lazily builds the peer ID and session on first access, so one
    /// identity is reused for the whole process. `.required` encryption
    /// keeps battle traffic private between the two devices.
    private func resolvedConnection() -> (peerID: MCPeerID, session: MCSession) {
        if let connection { return connection }
        let name = UIDevice.current.name
        let peerID = MCPeerID(displayName: name.isEmpty ? Localized("multiplayer.trainer") : name)
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        connection = (peerID, session)
        return (peerID, session)
    }

    /// Return a new `AsyncStream` that receives all future events. Each
    /// subscriber gets its own copy (broadcast). The stream auto-unregisters
    /// on termination so callers don't need to manually unsubscribe.
    func events() -> AsyncStream<MultipeerEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            self.subscribers[id] = continuation
            // `onTermination` can fire on any thread, so hop to the main
            // actor before mutating `subscribers`.
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.subscribers.removeValue(forKey: id)
                }
            }
        }
    }

    /// Advertise and browse simultaneously so both devices see each other
    /// immediately. Role is decided when a connection is established: the
    /// device that sent the invite becomes `.guest`, the one that accepted
    /// becomes `.host`.
    func startDiscovery() {
        stopDiscovery()
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    /// Stop both advertising and browsing. Safe to call when neither is active.
    func stopDiscovery() {
        stopHosting()
        stopBrowsing()
    }

    /// Stop advertising. Safe to call when not hosting.
    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
    }

    /// Stop browsing. Safe to call when not browsing.
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
    }

    /// Send an invite to a discovered peer. The inviter becomes the guest.
    func invite(_ peer: PeerHandle) {
        guard let browser, let peerID = peers[peer.id] else { return }
        role = .guest
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    /// Accept the latest pending invitation. The accepter becomes the host.
    func acceptInvitation() {
        role = .host
        invitationHandler?(true)
        invitationHandler = nil
    }

    /// Decline the latest pending invitation.
    func declineInvitation() {
        invitationHandler?(false)
        invitationHandler = nil
    }

    /// Send a typed message to all connected peers. Encoding or transport
    /// failures are logged but not thrown; the `.peerDisconnected` event
    /// covers loss-of-peer recovery. Uses `.reliable` delivery because the
    /// battle protocol depends on every message arriving, in order.
    func send(_ message: BattleMessage<PokemonSummary>) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            #if DEBUG
            print("MultipeerService.send error: \(error)")
            #endif
        }
    }

    /// Tear down the session and all discovery. Idempotent. Sends
    /// `.disconnect` first so the other peer can tell a deliberate exit from
    /// a dropped connection.
    func disconnect() {
        send(.disconnect)
        stopDiscovery()
        session.disconnect()
        role = nil
    }
}

extension MultipeerService: PeerDiscovering, PeerMessaging {}

// MARK: - Private
private extension MultipeerService {
    /// The stable handle for `peerID`, created on first sight.
    func handle(for peerID: MCPeerID) -> PeerHandle {
        if let handle = handles[peerID] { return handle }
        let handle = PeerHandle(id: UUID(), name: peerID.displayName)
        handles[peerID] = handle
        peers[handle.id] = peerID
        return handle
    }

    func emit(_ event: MultipeerEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    /// Hop a delegate callback (delivered on MultipeerConnectivity's private
    /// queue) onto the main actor. `DispatchQueue.main` keeps events FIFO;
    /// a `Task { @MainActor in }` per callback gives no ordering guarantee,
    /// so e.g. a `.message` could overtake the `.peerConnected` before it.
    /// `assumeIsolated` is safe because the main queue is the main actor's
    /// executor.
    nonisolated func onMain(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated(work) }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        onMain {
            switch state {
            case .connected:
                self.stopDiscovery()
                self.emit(.peerConnected(self.handle(for: peerID)))
                // First message on every connection, so the peer can reject
                // a different protocol version (see `MultiplayerSetupViewModel`).
                self.send(.hello(
                    protocolVersion: MultipeerProtocol.version,
                    displayName: self.myPeerID.displayName,
                    isHost: self.role == .host
                ))
            case .connecting:
                self.emit(.peerConnecting(self.handle(for: peerID)))
            case .notConnected:
                self.emit(.peerDisconnected(self.handle(for: peerID)))
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Decode on MC's queue and hop only the Sendable `BattleMessage`.
        guard let message = try? JSONDecoder().decode(BattleMessage<PokemonSummary>.self, from: data) else {
            #if DEBUG
            print("MultipeerService: dropped undecodable payload (\(data.count) bytes)")
            #endif
            return
        }
        onMain { self.emit(.message(message)) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Park the reply until the user answers the alert; see
        // `acceptInvitation()` / `declineInvitation()`.
        let reply = InvitationReply(invitationHandler)
        onMain {
            let session = self.session
            self.invitationHandler = { accepted in
                reply.respond(accepted, accepted ? session : nil)
            }
            self.emit(.invitationReceived(peerName: peerID.displayName))
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        onMain { self.emit(.advertisingFailed(error)) }
    }
}

/// Carries the advertiser's invitation callback onto the main actor.
/// MultipeerConnectivity documents the handler as callable from any
/// thread, and it's invoked at most once, so the unchecked conformance
/// is sound.
private final class InvitationReply: @unchecked Sendable {
    private let handler: (Bool, MCSession?) -> Void

    init(_ handler: @escaping (Bool, MCSession?) -> Void) {
        self.handler = handler
    }

    func respond(_ accepted: Bool, _ session: MCSession?) {
        handler(accepted, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        onMain { self.emit(.peerFound(self.handle(for: peerID))) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        onMain { self.emit(.peerLost(self.handle(for: peerID))) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        onMain { self.emit(.browsingFailed(error)) }
    }
}
