import SwiftUI
import SwiftData
import PokeBattleKit

/// Versus tab root. Shows nearby trainers via MultipeerConnectivity.
/// Tapping a trainer invites them; on connect a sheet walks both
/// players through pokemon + move selection before launching the battle.
struct MultiplayerSetupView: View {
    @State var viewModel: MultiplayerSetupViewModel

    var body: some View {
        NavigationStack {
            MultiplayerDiscoveryView(viewModel: viewModel)
                .applyPokedexStyling(title: "Gym")
                .foregroundStyle(.white)
                .task { viewModel.startListening() }
                .onAppear(perform: viewModel.startDiscovery)
                .onDisappear(perform: viewModel.stopDiscovery)
                .animation(.default, value: viewModel.phase)
                .sheet(isPresented: $viewModel.showPicker, onDismiss: viewModel.pickerDismissed) {
                    MultiplayerPickerSheet(viewModel: viewModel)
                }
                .navigationDestination(item: $viewModel.launch) { launch in
                    BattleView(viewModel: launch.viewModel)
                }
                .onChange(of: viewModel.launch) { _, new in
                    if new == nil, viewModel.phase == .launching {
                        viewModel.returnToLobby()
                    }
                }
                .alert(
                    "Battle challenge!",
                    isPresented: $viewModel.isShowingInvitation,
                    presenting: viewModel.pendingInvitation
                ) { _ in
                    Button("Accept", role: .confirm, action: viewModel.acceptInvitation)
                    Button("Decline", role: .cancel, action: viewModel.declineInvitation)
                } message: { invite in
                    Text(
                        "\(invite.peerName) wants to challenge you to a 1v1 battle."
                    )
                }
                .alert(
                    "Error",
                    isPresented: $viewModel.isShowingError,
                    presenting: viewModel.errorMessage
                ) { _ in
                    Button("OK") { viewModel.dismissError() }
                } message: { message in
                    Text(message)
                }
        }
    }
}

// MARK: - Discovery

/// Nearby-trainer list or empty/connecting state. Separate View struct so
/// peer list and invite changes don't re-evaluate the lobby's modifier chain.
private struct MultiplayerDiscoveryView: View {
    var viewModel: MultiplayerSetupViewModel

    var body: some View {
        Group {
            if viewModel.discoveredPeers.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    if viewModel.phase == .connecting {
                        PixelSpinner(text: "Connecting")
                            .frame(maxWidth: .infinity)
                    } else {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 28, height: 28)
                        Text("No trainers nearby")
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .font(.pixel14)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Nearby trainers", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.pixel12)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        ForEach(viewModel.discoveredPeers) { peer in
                            let isInvited = viewModel.invitedPeer == peer
                            Button {
                                viewModel.invite(peer)
                            } label: {
                                HStack {
                                    if isInvited {
                                        PixelSpinner()
                                    } else {
                                        Image(systemName: "person.fill")
                                            .frame(width: 24, height: 24)
                                    }
                                    Text(peer.name)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.pixel14)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.cardBackground)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.phase == .connecting)
                        }
                    }
                    .padding(.vertical)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Picker Sheet

/// Modal sheet for pokemon + move selection after connecting to a peer.
private struct MultiplayerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pokemon.id) private var allPokemon: [Pokemon]

    var viewModel: MultiplayerSetupViewModel
    @State private var selectedForMoves: Pokemon?

    var body: some View {
        NavigationStack {
            PokemonPickerGrid(pokemon: allPokemon) { pokemon in
                viewModel.selectPokemon(pokemon)
                selectedForMoves = pokemon
            }
            .applyPokedexStyling(title: "Pick your fighter", navColor: .darkGrey)
            .foregroundStyle(.white)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: dismiss.callAsFunction)
                }
            }
            .navigationDestination(item: $selectedForMoves) { pokemon in
                MultiplayerMovePickerView(viewModel: viewModel, pokemon: pokemon)
            }
        }
        .modifier(PickerSheetAutoDismiss(viewModel: viewModel))
    }
}

/// Dismisses the picker sheet on launch or error. Isolated in a modifier so
/// `phase` / `errorMessage` changes don't re-evaluate the picker grid.
private struct PickerSheetAutoDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var viewModel: MultiplayerSetupViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.phase) { _, newPhase in
                if newPhase == .launching {
                    dismiss()
                }
            }
            .onChange(of: viewModel.errorMessage) { _, error in
                if error != nil { dismiss() }
            }
    }
}

// MARK: - Move Picker

/// Separate View struct so `@Observable` tracking works through
/// `navigationDestination`. Wraps shared `MoveLoadoutView` with
/// multiplayer-specific button and waiting state.
private struct MultiplayerMovePickerView: View {
    var viewModel: MultiplayerSetupViewModel
    let pokemon: Pokemon

    var body: some View {
        MoveLoadoutView(
            pokemon: pokemon,
            moveSelection: viewModel.selection,
            isDisabled: viewModel.phase == .waitingForOpponent
        ) {
            submitButton
        }
        .applyPokedexStyling(title: "Pick moves", navColor: .darkGrey)
        .foregroundStyle(.white)
    }
}

// MARK: - Private
private extension MultiplayerMovePickerView {
    var submitButton: some View {
        let sel = viewModel.selection
        let ready = viewModel.selectedPokemon != nil && sel.isFull
        return PrimaryCapsuleButton(
            icon: "bolt.fill",
            title: "Ready",
            loadingTitle: "Waiting for opponent",
            isEnabled: ready,
            isLoading: viewModel.phase == .waitingForOpponent,
            action: viewModel.submitLoadout
        )
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }
}
