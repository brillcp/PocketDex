import SwiftUI
import SwiftData

/// A Pokémon's detail screen, built from the environment's container and
/// model context, optionally zooming from its grid cell.
///
/// The one place a detail view is built for navigation, so every grid
/// (pokedex, search, type lists, my team, evolutions) pushes the same
/// screen the same way.
struct PokemonDetailScreen: View {
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext

    let pokemon: Pokemon
    /// Zooms from the cell marked with `matchedTransitionSource(id: pokemon.id, in:)`
    /// in this namespace; `nil` for a plain push.
    var zoomNamespace: Namespace.ID?

    var body: some View {
        let detail = PokemonDetailView(
            viewModel: PokemonDetailViewModel(
                summary: pokemon,
                container: container,
                modelContext: modelContext
            )
        )
        if let zoomNamespace {
            detail.navigationTransition(.zoom(sourceID: pokemon.id, in: zoomNamespace))
        } else {
            detail
        }
    }
}

extension View {
    /// Pushes ``PokemonDetailScreen`` for `pokemon` while it's non-`nil`,
    /// zooming from its cell in `namespace` when given.
    func pokemonDetailDestination(item pokemon: Binding<Pokemon?>, zoomIn namespace: Namespace.ID? = nil) -> some View {
        navigationDestination(item: pokemon) { pokemon in
            PokemonDetailScreen(pokemon: pokemon, zoomNamespace: namespace)
        }
    }
}
