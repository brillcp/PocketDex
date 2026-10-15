import SwiftUI
import SwiftData

/// "My team" sheet (opened from the pokedex toolbar) showing bookmarked
/// Pokemon; the team is stored as `isBookmarked`. The `@Query` predicate filters in the store and keeps the grid
/// live: unbookmarking in a pushed detail view removes the cell on return.
struct MyTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext
    @Namespace private var namespace

    @Query(
        filter: #Predicate<Pokemon> { $0.isBookmarked },
        sort: \.id
    ) private var bookmarks: [Pokemon]

    @State private var selectedPokemon: Pokemon?

    var body: some View {
        NavigationStack {
            PokemonPickerGrid(
                pokemon: bookmarks,
                namespace: namespace
            ) { pokemon in
                selectedPokemon = pokemon
            }
                .background {
                    if bookmarks.isEmpty {
                        Text("No team members")
                            .foregroundStyle(.secondary)
                            .font(.pixel14)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: dismiss.callAsFunction)
                    }
                }
                .applyPokedexStyling(title: Tabs.myTeam.title, navColor: .darkGrey)
                .navigationDestination(item: $selectedPokemon) { pokemon in
                    PokemonDetailView(
                        viewModel: PokemonDetailViewModel(
                            summary: pokemon,
                            container: container,
                            modelContext: modelContext
                        )
                    )
                    .navigationTransition(.zoom(sourceID: pokemon.id, in: namespace))
                }
        }
        // Opaque sheet: the grid's own background fades out with it during
        // the zoom to and from the detail view, which would otherwise show
        // the see-through glass sheet behind.
        .presentationBackground(Color.darkGrey)
    }
}

#Preview {
    MyTeamView()
}
