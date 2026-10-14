import Foundation
@preconcurrency import MultipeerConnectivity
import SwiftUI

/// Lightweight invitation handle for SwiftUI alert presentation.
struct PendingInvitation: Identifiable, Equatable {
    let id = UUID()
    let peerName: String
}

/// Role this device plays in the session. Advertiser = `.host`, browser =
/// `.guest`. Decided at the moment a peer chooses to host or browse.
enum MultipeerRole: Sendable {
    case host
    case guest
}

/// Typed events emitted by MultipeerConnectivity delegate callbacks.
/// Consumed by view models via the `events()` AsyncStream.
enum MultipeerEvent {
    case peerFound(MCPeerID)
    case peerLost(MCPeerID)
    case peerConnecting(MCPeerID)
    case peerConnected(MCPeerID)
    case peerDisconnected(MCPeerID)
    case invitationReceived(peerName: String)
    case advertisingFailed(Error)
    case browsingFailed(Error)
    case message(BattleMessage)
}

/// Process-wide MultipeerConnectivity wrapper. Owns the `MCSession`,
/// advertiser, and browser; emits typed `MultipeerEvent`s via AsyncStream
/// for consumption by view models.
@MainActor
@Observable
final class MultipeerService: NSObject {
    private static let serviceType = "pokedex-vs"

    private var subscribers: [UUID: AsyncStream<MultipeerEvent>.Continuation] = [:]
    @ObservationIgnored private var connection: (peerID: MCPeerID, session: MCSession)?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var invitationHandler: ((Bool) -> Void)?

    private(set) var role: MultipeerRole?
    var localDisplayName: String { myPeerID.displayName }

    /// Nonisolated so `AppContainer.live` (and the `\.container`
    /// environment default) can be built without the main actor. The peer
    /// and session are created on first use instead, on the main actor,
    /// because the display name comes from `UIDevice`.
    nonisolated override init() {
        super.init()
    }

    private var myPeerID: MCPeerID { resolvedConnection().peerID }
    private var session: MCSession { resolvedConnection().session }

    private func resolvedConnection() -> (peerID: MCPeerID, session: MCSession) {
        if let connection { return connection }
        let name = UIDevice.current.name
        let peerID = MCPeerID(displayName: name.isEmpty ? "Trainer" : name)
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
    func invite(_ peer: MCPeerID) {
        guard let browser else { return }
        role = .guest
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
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
    /// failures are logged but not thrown; the receive stream's `.disconnect`
    /// path covers loss-of-peer recovery.
    func send(_ message: BattleMessage) {
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

    /// Tear down the session and all discovery. Idempotent.
    func disconnect() {
        send(.disconnect)
        stopDiscovery()
        session.disconnect()
        role = nil
    }
}

// MARK: - Private
private extension MultipeerService {
    func emit(_ event: MultipeerEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    /// Hop a delegate callback (delivered on MultipeerConnectivity's private
    /// queue) onto the main actor. `DispatchQueue.main` keeps events FIFO.
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
                self.emit(.peerConnected(peerID))
            case .connecting:
                self.emit(.peerConnecting(peerID))
            case .notConnected:
                self.emit(.peerDisconnected(peerID))
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(BattleMessage.self, from: data) else {
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
        onMain { self.emit(.peerFound(peerID)) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        onMain { self.emit(.peerLost(peerID)) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        onMain { self.emit(.browsingFailed(error)) }
    }
}
