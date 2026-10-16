import Foundation
import PokeBattleKit
import SwiftUI

/// Discrete states the multiplayer lobby moves through.
enum MultiplayerSetupPhase: Equatable {
    /// Advertising and browsing for nearby trainers.
    case discovering
    /// An invite was sent or accepted; waiting for the session to connect.
    case connecting
    /// Connected; choosing a Pokémon and moves in the picker sheet.
    case picking
    /// Own loadout sent; waiting for the peer's.
    case waitingForOpponent
    /// Both loadouts exchanged; the battle view model is being pushed.
    case launching
}

/// Composite payload the lobby hands back to the navigation host once both
/// peers have exchanged challenges and the battle view model is wired up.
struct MultiplayerLaunch: Identifiable, Hashable {
    let id = UUID()
    let viewModel: MultiplayerBattleViewModel

    static func == (lhs: MultiplayerLaunch, rhs: MultiplayerLaunch) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Drives `MultiplayerSetupView`: the lobby. Owns peer discovery,
/// invitations, the connection lifecycle, errors, and pushing the battle.
/// The fighter/move picking and challenge exchange live in `handshake`;
/// this forwards the peer's challenge messages to it and acts on the outcome.
/// Roles come from the multipeer service (the device that accepted the
/// invite hosts).
@MainActor
@Observable
final class MultiplayerSetupViewModel {
    private let multipeer: any MultipeerServicing
    private var listenTask: Task<Void, Never>?
    private var connectedPeerName: String?
    private var receivedBattleEnded: Bool = false

    let handshake: MultiplayerHandshake

    var phase: MultiplayerSetupPhase = .discovering
    var showPicker: Bool = false
    var errorMessage: String?
    var invitedPeer: PeerHandle?
    var launch: MultiplayerLaunch?
    var discoveredPeers: [PeerHandle] = []
    var pendingInvitation: PendingInvitation?

    init(multipeer: any MultipeerServicing, handshake: MultiplayerHandshake) {
        self.multipeer = multipeer
        self.handshake = handshake
    }

    isolated deinit {
        listenTask?.cancel()
    }

    /// Begin listening for multipeer events, for the view model's lifetime
    /// (it keeps listening while a battle is pushed over the lobby, and
    /// `deinit` cancels it). Call from the view's `.task`; later calls are
    /// no-ops.
    func startListening() {
        guard listenTask == nil else { return }
        let stream = multipeer.events()
        listenTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }
}

// MARK: - Lobby actions
extension MultiplayerSetupViewModel {
    /// Start advertising + browsing. Called when the battle tab appears.
    func startDiscovery() {
        guard phase == .discovering else { return }
        discoveredPeers = []
        multipeer.startDiscovery()
    }

    /// Stop advertising + browsing. Called when the battle tab disappears.
    func stopDiscovery() {
        multipeer.stopDiscovery()
    }

    func invite(_ peer: PeerHandle) {
        invitedPeer = peer
        multipeer.invite(peer)
        phase = .connecting
    }

    func acceptInvitation() {
        multipeer.acceptInvitation()
        pendingInvitation = nil
        phase = .connecting
    }

    func declineInvitation() {
        multipeer.declineInvitation()
        pendingInvitation = nil
    }

    /// Called when the picker sheet is dismissed without completing.
    func pickerDismissed() {
        guard phase != .launching, launch == nil else { return }
        multipeer.disconnect()
        resetSelection()
        phase = .discovering
        startDiscovery()
    }

    func dismissError() {
        errorMessage = nil
        if phase == .discovering {
            startDiscovery()
        }
    }

    /// Called when navigating back from a finished battle.
    func returnToLobby() {
        multipeer.disconnect()
        reset()
        startDiscovery()
    }

    func selectPokemon(_ pokemon: Pokemon) {
        handshake.select(pokemon)
        phase = .picking
    }

    /// Send the locally chosen loadout to the peer.
    func submitLoadout() {
        guard let outcome = handshake.submit() else { return }
        apply(outcome)
    }

    /// Derived from the `.battleEnded` turn message or launch VM's winner.
    var battleEnded: Bool { receivedBattleEnded || launch?.viewModel.winner != nil }

    /// Drives the invitation alert. Dismissing clears the pending invitation.
    var isShowingInvitation: Bool {
        get { pendingInvitation != nil }
        set { if !newValue { pendingInvitation = nil } }
    }

    /// Drives the error alert. Dismissing clears the error message.
    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }
}

// MARK: - Private
private extension MultiplayerSetupViewModel {
    func handle(_ event: MultipeerEvent) async {
        switch event {
        case .peerFound(let peer):
            if !discoveredPeers.contains(peer) {
                discoveredPeers.append(peer)
            }
        case .peerLost(let peer):
            discoveredPeers.removeAll { $0 == peer }
        case .peerConnecting:
            break
        case .peerConnected(let peer):
            connectedPeerName = peer.name
            discoveredPeers = []
            receivedBattleEnded = false
            showPicker = true
        case .peerDisconnected:
            if phase == .connecting {
                inviteDeclined()
            } else if phase != .discovering {
                connectionLost()
            }
        case .invitationReceived(let peerName):
            pendingInvitation = PendingInvitation(peerName: peerName)
        case .advertisingFailed(let error):
            errorMessage = error.localizedDescription
        case .browsingFailed(let error):
            errorMessage = error.localizedDescription
        case .message(let battleMessage):
            handleBattleMessage(battleMessage)
        }
    }

    func handleBattleMessage(_ message: BattleMessage<PokemonSummary>) {
        switch message {
        case .hello(let version, _, _):
            if version != MultipeerProtocol.version {
                errorMessage = Localized("multiplayer.error.protocolVersion")
                multipeer.disconnect()
                showPicker = false
                reset()
            }
        case .challengeProposed(let payload), .challengeAccepted(let payload):
            if let outcome = handshake.receive(payload) { apply(outcome) }
        case .challengeDeclined:
            errorMessage = Localized("multiplayer.challengeDeclined", peerName)
            showPicker = false
            reset()
        case .disconnect:
            guard phase != .discovering else { return }
            if !battleEnded {
                errorMessage = Localized("multiplayer.canceled", peerName)
            }
            showPicker = false
            reset()
            startDiscovery()
        case .turn(.battleEnded):
            receivedBattleEnded = true
        case .turn, .rematch:
            break
        }
    }

    /// Acts on a handshake step: wait, push the battle, or reject the
    /// peer's loadout.
    func apply(_ outcome: MultiplayerHandshake.Outcome) {
        switch outcome {
        case .waiting:
            phase = .waitingForOpponent
        case .launch(let viewModel):
            phase = .launching
            showPicker = false
            launch = MultiplayerLaunch(viewModel: viewModel)
        case .invalidPeerLoadout:
            errorMessage = Localized("multiplayer.error.invalidLoadout")
            showPicker = false
            reset()
        }
    }

    /// Peer we invited declined (MC disconnected while connecting).
    func inviteDeclined() {
        let name = invitedPeer?.name ?? Localized("multiplayer.trainer")
        invitedPeer = nil
        phase = .discovering
        errorMessage = Localized("multiplayer.inviteDeclined", name)
        startDiscovery()
    }

    /// MC dropped unexpectedly during picking, waiting, or battle.
    func connectionLost() {
        if !battleEnded {
            errorMessage = Localized("multiplayer.canceled", peerName)
        }
        showPicker = false
        reset()
        startDiscovery()
    }

    /// The connected peer's name, for error messages.
    var peerName: String {
        connectedPeerName ?? Localized("multiplayer.opponent")
    }

    func reset() {
        invitedPeer = nil
        phase = .discovering
        discoveredPeers = []
        resetSelection()
    }

    func resetSelection() {
        handshake.reset()
        connectedPeerName = nil
        launch = nil
    }
}
