import SwiftUI
import SwiftData

/// "My team" screen, pushed from the pokedex toolbar, showing bookmarked
/// Pokemon; the team is stored as `isBookmarked`. Pushed rather than a
/// sheet so the zoom into a team member's detail works. The `@Query` predicate filters in the store and keeps the grid
/// live: unbookmarking in a pushed detail view removes the cell on return.
/// "My team" title and symbol, shared by the toolbar button, this screen
/// and the fighter picker's team section.
enum MyTeam {
    static let title = "My team"
    static let icon = "person.2.fill"
}

struct MyTeamView: View {
    @Namespace private var namespace

    @Query(
        filter: #Predicate<Pokemon> { $0.isBookmarked },
        sort: \.id
    ) private var team: [Pokemon]

    /// When set (the side-by-side layout in regular width), taps write to
    /// this binding instead of pushing the detail view.
    var selection: Binding<Pokemon?>? = nil

    @State private var selectedPokemon: Pokemon?

    var body: some View {
        PokemonPickerGrid(
            pokemon: team,
            namespace: namespace,
            // A team is a handful of Pokémon; no search field needed.
            isSearchable: false
        ) { pokemon in
            if let selection {
                selection.wrappedValue = pokemon
            } else {
                selectedPokemon = pokemon
            }
        }
        .background {
            if team.isEmpty {
                Text("No team members")
                    .foregroundStyle(.secondary)
                    .font(.pixel14)
            }
        }
        .applyPokedexStyling(title: MyTeam.title, navColor: .darkGrey)
        .pokemonDetailDestination(item: $selectedPokemon, zoomIn: namespace)
    }
}
