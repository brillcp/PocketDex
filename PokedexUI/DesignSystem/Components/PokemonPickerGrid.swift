import SwiftUI

/// Generic Pokemon grid. Callers provide column layout and cell content
/// via `@ViewBuilder`. Handles only scrolling and layout; navigation,
/// search, and loading overlays are the caller's responsibility.
///
/// Rows are identified by Pokémon id, so re-sorting or filtering animates
/// cells to new positions instead of rebuilding them. One haptic trigger
/// for the whole grid (via a simultaneous tap gesture) avoids attaching
/// `.sensoryFeedback` to every cell.
struct PokemonGrid<Cell: View>: View {
    let pokemon: [Pokemon]
    var grid: GridLayout = .three
    var contentPadding: EdgeInsets = .init()
    @ViewBuilder let cell: (Pokemon) -> Cell

    @State private var tapTrigger = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid.layout, spacing: grid.spacing) {
                ForEach(pokemon, id: \.id) { pokemon in
                    cell(pokemon)
                        .simultaneousGesture(TapGesture().onEnded { tapTrigger.toggle() })
                }
            }
            .padding(contentPadding)
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .sensoryFeedback(.impact(weight: .light), trigger: tapTrigger)
    }
}

/// Searchable Pokemon grid used by opponent picker, multiplayer fighter picker,
/// and bookmarks. Wraps `PokemonGrid` with a toolbar search bar and
/// haystack-based filtering.
///
/// Callers that manage their own search (e.g. SearchView) should use
/// `PokemonGrid` directly instead.
///
/// Unlike the Search tab, the haystacks here are built on the main actor on
/// first appear, as a one-time pass over the models already passed in
/// (later keystrokes only run substring checks against it).
struct PokemonPickerGrid: View {
    let pokemon: [Pokemon]
    var namespace: Namespace.ID?
    let onSelect: (Pokemon) -> Void

    @State private var searchText = ""
    @State private var index: [(pokemon: Pokemon, haystack: String)] = []
    @State private var filteredPokemon: [Pokemon]?

    var body: some View {
        PokemonGrid(pokemon: displayedPokemon) { pokemon in
            Button {
                onSelect(pokemon)
            } label: {
                PokemonSpriteCard(pokemon: pokemon)
                    .applyTransitionSource(id: pokemon.id, namespace: namespace)
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $searchText, placement: .toolbar)
        .scrollDismissesKeyboard(.immediately)
        .onAppear(perform: buildIndex)
        .onChange(of: searchText, updateFilteredPokemon)
    }
}

// MARK: - Private
private extension PokemonPickerGrid {
    var displayedPokemon: [Pokemon] {
        filteredPokemon ?? pokemon
    }

    func updateFilteredPokemon() {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map { $0.normalize }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            filteredPokemon = nil
            return
        }
        filteredPokemon = index.compactMap { entry in
            terms.allSatisfy { entry.haystack.contains($0) } ? entry.pokemon : nil
        }
    }

    func buildIndex() {
        guard index.isEmpty else { return }
        index = pokemon.map { ($0, Pokemon.searchHaystack(for: $0)) }
    }
}

// MARK: - Helpers
extension View {
    @ViewBuilder
    func applyTransitionSource(id: Int, namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
