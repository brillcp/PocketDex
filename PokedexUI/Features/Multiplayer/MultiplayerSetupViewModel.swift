import Foundation
import MultipeerConnectivity
import PokeBattleKit
import SwiftUI

/// Discrete states the multiplayer lobby moves through.
enum MultiplayerSetupPhase: Equatable {
    case discovering
    case connecting
    case picking
    case waitingForOpponent
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

/// Drives `MultiplayerSetupView`. Owns peer discovery state, connection
/// lifecycle, the local pokemon + move selection, the wire handshake, and
/// the assembly of the live battle view model once both peers have submitted
/// their loadouts.
@MainActor
@Observable
final class MultiplayerSetupViewModel {
    private let container: AppContainer
    private var listenTask: Task<Void, Never>?
    private var ownChallengeSent: Bool = false
    private var peerChallenge: ChallengePayload?
    private var connectedPeerName: String?
    private var receivedBattleEnded: Bool = false

    let multipeer: MultipeerService
    let selection = MoveSelection()

    var phase: MultiplayerSetupPhase = .discovering
    var showPicker: Bool = false
    var errorMessage: String?
    var selectedPokemon: Pokemon?
    var invitedPeer: PeerHandle?
    var launch: MultiplayerLaunch?
    var discoveredPeers: [PeerHandle] = []
    var pendingInvitation: PendingInvitation?

    init(container: AppContainer) {
        self.container = container
        self.multipeer = container.multipeerService
    }

    /// Begin listening for multipeer events. Call once from the view's `.task`
    /// modifier so the listen loop is tied to view lifetime, not init.
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
    /// Start advertising + browsing. Called when the versus tab appears.
    func startDiscovery() {
        guard phase == .discovering else { return }
        discoveredPeers = []
        multipeer.startDiscovery()
    }

    /// Stop advertising + browsing. Called when the versus tab disappears.
    func stopDiscovery() {
        multipeer.stopDiscovery()
    }

    func invite(_ peer: PeerHandle) {
        invitedPeer = peer
        multipeer.invite(peer.id)
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
        selectedPokemon = pokemon
        selection.load(for: pokemon)
        phase = .picking
    }

    /// Send the locally chosen loadout to the peer.
    func submitLoadout() {
        guard let pokemon = selectedPokemon,
              selection.isFull,
              let role = multipeer.role
        else { return }
        let payload = ChallengePayload(
            pokemon: PokemonSummary(pokemon: pokemon),
            moveNames: selection.selectionOrder
        )
        switch role {
        case .host:  multipeer.send(.challengeProposed(payload))
        case .guest: multipeer.send(.challengeAccepted(payload))
        }
        ownChallengeSent = true
        if peerChallenge != nil {
            phase = .launching
            tryLaunch()
        } else {
            phase = .waitingForOpponent
        }
    }

    /// Derived from `.battleEnded` message or launch VM's winner.
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
        case .peerFound(let peerID):
            let handle = PeerHandle(id: peerID)
            if !discoveredPeers.contains(handle) {
                discoveredPeers.append(handle)
            }
        case .peerLost(let peerID):
            discoveredPeers.removeAll { $0.id == peerID }
        case .peerConnecting:
            break
        case .peerConnected(let peerID):
            connectedPeerName = peerID.displayName
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
            await handleBattleMessage(battleMessage)
        }
    }

    func handleBattleMessage(_ message: BattleMessage) async {
        switch message {
        case .hello(let version, _, _):
            if version != MultipeerProtocol.version {
                errorMessage = String(
                    localized: "Opponent uses a different protocol version.",
                    comment: "Error alert message when the connected peer runs an incompatible app version."
                )
                multipeer.disconnect()
                showPicker = false
                reset()
            }
        case .challengeProposed(let payload), .challengeAccepted(let payload):
            peerChallenge = payload
            if ownChallengeSent {
                phase = .launching
                tryLaunch()
            }
        case .challengeDeclined:
            let name = connectedPeerName ?? Self.opponentFallbackName
            errorMessage = String(
                localized: "\(name) declined the challenge.",
                comment: "Error alert message. The variable is the opponent's device name."
            )
            showPicker = false
            reset()
        case .disconnect:
            guard phase != .discovering else { return }
            if !battleEnded {
                errorMessage = canceledMessage()
            }
            showPicker = false
            reset()
            startDiscovery()
        case .battleEnded:
            receivedBattleEnded = true
        case .moveCommitted, .roundResolved, .rematch:
            break
        }
    }

    /// Peer we invited declined (MC disconnected while connecting).
    func inviteDeclined() {
        let name = invitedPeer?.name ?? String(
            localized: "Trainer",
            comment: "Fallback name for an invited nearby player whose device name is unknown."
        )
        invitedPeer = nil
        phase = .discovering
        errorMessage = String(
            localized: "\(name) declined the battle.",
            comment: "Error alert message. The variable is the invited player's device name."
        )
        startDiscovery()
    }

    /// MC dropped unexpectedly during picking, waiting, or battle.
    func connectionLost() {
        if !battleEnded {
            errorMessage = canceledMessage()
        }
        showPicker = false
        reset()
        startDiscovery()
    }

    func tryLaunch() {
        guard ownChallengeSent,
              let peerChallenge,
              let role = multipeer.role,
              let pokemon = selectedPokemon
        else { return }
        let selfMoves = selection.selectedMoves
        let peerMoves = peerChallenge.moveNames.compactMap { PokeBattleKit.move(named: $0) }
        guard peerMoves.count == selection.maxSelections else {
            errorMessage = String(
                localized: "Opponent sent an invalid loadout.",
                comment: "Error alert message when the peer's chosen moves can't be resolved."
            )
            showPicker = false
            reset()
            return
        }
        showPicker = false
        let viewModel = MultiplayerBattleViewModel(
            role: role,
            selfSummary: PokemonSummary(pokemon: pokemon),
            selfMoves: selfMoves,
            peerSummary: peerChallenge.pokemon,
            peerMoves: peerMoves,
            multipeer: multipeer,
            container: container
        )
        launch = MultiplayerLaunch(viewModel: viewModel)
    }

    static var opponentFallbackName: String {
        String(localized: "Opponent", comment: "Fallback name for the connected player whose device name is unknown.")
    }

    func canceledMessage() -> String {
        let name = connectedPeerName ?? Self.opponentFallbackName
        return String(
            localized: "\(name) canceled.",
            comment: "Error alert message when the opponent leaves. The variable is the opponent's device name."
        )
    }

    func reset() {
        invitedPeer = nil
        phase = .discovering
        discoveredPeers = []
        resetSelection()
    }

    func resetSelection() {
        selectedPokemon = nil
        selection.load(ranked: [])
        ownChallengeSent = false
        peerChallenge = nil
        connectedPeerName = nil
        launch = nil
    }
}

/// Identifiable wrapper around `MCPeerID` for stable use in SwiftUI lists.
struct PeerHandle: Identifiable, Hashable {
    let id: MCPeerID
    var name: String { id.displayName }
}
