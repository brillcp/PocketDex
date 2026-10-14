import SwiftUI
import SwiftData

/// Favourites sheet (opened from the pokedex toolbar) showing bookmarked
/// Pokemon. The `@Query` predicate filters in the store and keeps the grid
/// live: unbookmarking in a pushed detail view removes the cell on return.
struct BookmarksView: View {
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
                        Text("No favourites")
                            .foregroundStyle(.secondary)
                            .font(.pixel14)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: dismiss.callAsFunction)
                    }
                }
                .applyPokedexStyling(title: Tabs.favourites.title, navColor: .darkGrey)
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
}

#Preview {
    BookmarksView()
}
