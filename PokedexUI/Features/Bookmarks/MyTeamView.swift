import SwiftUI
import SwiftData

/// "My team" screen, pushed from the pokedex toolbar, showing bookmarked
/// Pokemon; the team is stored as `isBookmarked`. Pushed rather than a
/// sheet so the zoom into a team member's detail works. The `@Query` predicate filters in the store and keeps the grid
/// live: unbookmarking in a pushed detail view removes the cell on return.
struct MyTeamView: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext
    @Namespace private var namespace

    @Query(
        filter: #Predicate<Pokemon> { $0.isBookmarked },
        sort: \.id
    ) private var bookmarks: [Pokemon]

    @State private var selectedPokemon: Pokemon?

    var body: some View {
        PokemonPickerGrid(
            pokemon: bookmarks,
            namespace: namespace,
            // A team is a handful of Pokémon; no search field needed.
            isSearchable: false
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
}

#Preview {
    NavigationStack {
        MyTeamView()
    }
}
