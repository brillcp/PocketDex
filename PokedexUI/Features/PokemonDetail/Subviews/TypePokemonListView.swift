import SwiftUI
import SwiftData

/// Grid of all Pokemon matching a given type, pushed from a tappable
/// type chip in the detail view. Uses the same `PokemonSpriteCard` cells
/// as search and my team.
struct TypePokemonListView: View {
    let typeName: String

    @Namespace private var namespace
    @Query private var pokemonOfType: [Pokemon]
    @State private var selectedPokemon: Pokemon?

    /// Filters in the store via the query predicate instead of filtering
    /// the whole corpus on every body evaluation.
    init(typeName: String) {
        self.typeName = typeName
        _pokemonOfType = Query(
            filter: #Predicate<Pokemon> { pokemon in
                pokemon.types.contains { $0.type.name == typeName }
            },
            sort: \.id
        )
    }

    var body: some View {
        PokemonGrid(pokemon: pokemonOfType) { pokemon in
            Button {
                selectedPokemon = pokemon
            } label: {
                PokemonSpriteCard(pokemon: pokemon)
                    .applyTransitionSource(id: pokemon.id, namespace: namespace)
            }
            .buttonStyle(.plain)
        }
        .applyPokedexStyling(title: typeName.capitalized, navColor: .darkGrey)
        .pokemonDetailDestination(item: $selectedPokemon, zoomIn: namespace)
    }
}
