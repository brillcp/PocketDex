import Foundation
import PokeBattleKit

/// The battle handshake once two devices are connected: this device's
/// fighter and moves, the challenge exchange, and building the battle once
/// both loadouts are in. The lobby (`MultiplayerSetupViewModel`) owns one and
/// forwards the peer's challenge messages to it.
///
/// Whichever side finishes picking first sends its `ChallengePayload` (host
/// as `.challengeProposed`, guest as `.challengeAccepted`) and waits; when a
/// device holds both its own and the peer's payload it builds a
/// `MultiplayerBattleViewModel` locally. Only a `PokemonSummary` snapshot and
/// move names cross the wire; each device rebuilds `Move`s from its own
/// catalogue.
@MainActor
@Observable
final class MultiplayerHandshake {
    /// What a step of the handshake leads to.
    enum Outcome {
        /// Own loadout sent; the peer's hasn't arrived yet.
        case waiting
        /// Both loadouts are in: push this battle.
        case launch(MultiplayerBattleViewModel)
        /// The peer's moves aren't a valid loadout here.
        case invalidPeerLoadout
    }

    /// Both loadouts, from this device's side: what a battle is built from.
    struct Match {
        let role: MultipeerRole
        let selfSummary: PokemonSummary
        let selfMoves: [Move]
        let peerSummary: PokemonSummary
        let peerMoves: [Move]
    }

    private let multipeer: any PeerMessaging
    private let catalog: any BattleCatalogReading
    private let movePools: MovePoolBuilder
    private let makeBattle: @MainActor (Match) -> MultiplayerBattleViewModel
    private var peerChallenge: ChallengePayload?
    private(set) var ownChallengeSent = false

    let selection = MoveSelection()
    private(set) var selectedPokemon: Pokemon?

    /// For move effectiveness labels; `nil` while the catalogue loads.
    var typeChart: TypeChart? { catalog.typeChart }

    /// `makeBattle` builds the battle once both loadouts are in (see
    /// `ViewModelFactory`).
    init(
        multipeer: any PeerMessaging,
        catalog: any BattleCatalogReading,
        movePools: MovePoolBuilder,
        makeBattle: @escaping @MainActor (Match) -> MultiplayerBattleViewModel
    ) {
        self.multipeer = multipeer
        self.catalog = catalog
        self.movePools = movePools
        self.makeBattle = makeBattle
    }

    func select(_ pokemon: Pokemon) {
        selectedPokemon = pokemon
        selection.load(ranked: movePools.moves(for: pokemon))
    }

    /// Send the chosen loadout to the peer. `nil` if there's nothing to send
    /// yet (no full loadout, or not connected).
    func submit() -> Outcome? {
        guard let pokemon = selectedPokemon,
              selection.isFull,
              let role = multipeer.role
        else { return nil }
        let payload = ChallengePayload(
            pokemon: PokemonSummary(pokemon: pokemon),
            moveNames: selection.selectionOrder
        )
        switch role {
        case .host:  multipeer.send(.challengeProposed(payload))
        case .guest: multipeer.send(.challengeAccepted(payload))
        }
        ownChallengeSent = true
        return peerChallenge == nil ? .waiting : tryLaunch()
    }

    /// The peer's loadout arrived. `nil` while ours hasn't been sent.
    func receive(_ payload: ChallengePayload) -> Outcome? {
        peerChallenge = payload
        return ownChallengeSent ? tryLaunch() : nil
    }

    func reset() {
        selectedPokemon = nil
        selection.load(ranked: [])
        ownChallengeSent = false
        peerChallenge = nil
    }
}

// MARK: - Private
private extension MultiplayerHandshake {
    func tryLaunch() -> Outcome? {
        guard let peerChallenge,
              let role = multipeer.role,
              let pokemon = selectedPokemon
        else { return nil }
        let peerMoves = peerChallenge.moveNames.compactMap { catalog.move(named: $0) }
        // The peer's Pokémon may know fewer than four usable moves.
        guard !peerMoves.isEmpty, peerMoves.count == peerChallenge.moveNames.count,
              peerMoves.count <= selection.loadoutSize
        else { return .invalidPeerLoadout }
        return .launch(makeBattle(Match(
            role: role,
            selfSummary: PokemonSummary(pokemon: pokemon),
            selfMoves: selection.selectedMoves,
            peerSummary: peerChallenge.pokemon,
            peerMoves: peerMoves
        )))
    }
}
