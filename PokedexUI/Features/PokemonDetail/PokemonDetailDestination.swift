import SwiftUI
import SwiftData

/// A Pokémon's detail screen, built by the environment's view model
/// factory, optionally zooming from its grid cell.
///
/// The one place a detail view is built for navigation, so every grid
/// (pokedex, search, type lists, my team, evolutions) pushes the same
/// screen the same way.
struct PokemonDetailScreen: View {
    @Environment(\.viewModels) private var viewModels

    let pokemon: Pokemon
    /// Zooms from the cell marked with `matchedTransitionSource(id: pokemon.id, in:)`
    /// in this namespace; `nil` for a plain push.
    var zoomNamespace: Namespace.ID?

    var body: some View {
        let detail = PokemonDetailView(
            viewModel: viewModels.pokemonDetail(for: pokemon)
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
