import SwiftUI
import SwiftData

/// Search tab backed by its own SwiftData `@Query` against the full corpus.
///
/// The view owns the query (so SwiftData pushes store changes to it) and
/// hands each new result to the view model, which matches the typed text
/// against precomputed haystacks. The search field is applied to the
/// `NavigationStack`, so in the search tab it sits above the keyboard and
/// stays out of the other tabs.
struct SearchView<ViewModel: SearchViewModelProtocol>: View {
    @FocusState private var isSearchFocused: Bool
    @Namespace private var namespace
    @Environment(\.featureFlags) private var featureFlags
    @Query(sort: \Pokemon.id) private var corpus: [Pokemon]

    @State var viewModel: ViewModel
    @State private var selectedPokemon: Pokemon?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    emptyState
                } else {
                    PokemonGrid(pokemon: viewModel.filtered) { pokemon in
                        Button {
                            selectedPokemon = pokemon
                        } label: {
                            PokemonSpriteCard(pokemon: pokemon, hidesName: featureFlags.silhouetteEnabled)
                                .applyTransitionSource(id: pokemon.id, namespace: namespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .font(.pixel14)
            // Re-runs whenever the stored rows change, e.g. once the first
            // launch import finishes while this tab is already open.
            .task(id: corpus) {
                await viewModel.updateCorpus(corpus)
            }
            .scrollDismissesKeyboard(.immediately)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.query)
            .applyPokedexStyling(title: Tabs.search.title)
            .pokemonDetailDestination(item: $selectedPokemon, zoomIn: namespace)
        }
        .searchable(text: $viewModel.query)
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search, viewModel.recordSearch)
        .onChange(of: isSearchFocused) { old, new in
            guard old, !new, !viewModel.query.isEmpty else { return }
            viewModel.recordSearch()
        }
    }
}

// MARK: - Private
private extension SearchView {
    var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s24) {
                if !viewModel.suggestedPokemon.isEmpty {
                    SuggestedPokemonSection(pokemon: viewModel.suggestedPokemon, namespace: namespace) {
                        selectedPokemon = $0
                    }
                }
                SuggestedTermsSection(terms: ViewModel.suggestedTerms, onSelect: selectSuggestedTerm)
                if !viewModel.recentSearches.isEmpty {
                    RecentSearchesSection(
                        terms: viewModel.recentSearches,
                        onSelect: { viewModel.query = $0 },
                        onClear: viewModel.clearRecentSearches
                    )
                } else {
                    Text("Search names, types, habitats or abilities")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, DesignKit.Spacing.Primitive.s56 + DesignKit.Spacing.Primitive.s24)
                        .padding(.horizontal, DesignKit.Spacing.Primitive.s16)
                        .lineHeight(.loose)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, DesignKit.Spacing.Primitive.s16)
        }
        .scrollIndicators(.hidden)
    }

    func selectSuggestedTerm(_ term: String) {
        viewModel.query = term
        viewModel.recordSearch()
    }
}

/// Curated search-term chips shown in the empty state.
private struct SuggestedTermsSection: View {
    let terms: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
            SearchSectionHeader(title: "Try searching for", systemImage: "magnifyingglass")
            FlowLayout(spacing: DesignKit.Spacing.Primitive.s6) {
                ForEach(terms, id: \.self) { term in
                    Button {
                        onSelect(term)
                    } label: {
                        Chip(term, style: .accent, size: .medium)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignKit.Spacing.Primitive.s16)
    }
}

/// Random suggested Pokemon cards shown in the empty state.
private struct SuggestedPokemonSection: View {
    let pokemon: [Pokemon]
    let namespace: Namespace.ID
    /// Pushes through the search stack's single detail destination.
    let onSelect: (Pokemon) -> Void
    @Environment(\.featureFlags) private var featureFlags

    var body: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
            SearchSectionHeader(title: "Suggested", systemImage: "sparkles.2")
                .padding(.horizontal, DesignKit.Spacing.Primitive.s16)
            LazyVGrid(columns: GridLayout.two.layout, spacing: GridLayout.two.spacing) {
                ForEach(pokemon, id: \.id) { pokemon in
                    Button {
                        onSelect(pokemon)
                    } label: {
                        PokemonSpriteCard(pokemon: pokemon, hidesName: featureFlags.silhouetteEnabled)
                            .matchedTransitionSource(id: pokemon.id, in: namespace)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Recent search terms with a clear button.
private struct RecentSearchesSection: View {
    let terms: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
            HStack {
                SearchSectionHeader(title: "Recent", systemImage: "clock.arrow.circlepath")
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "trash.fill")
                        .font(.pixel16)
                        .foregroundStyle(Color.pokedexRed)
                }
            }
            .padding(.horizontal, DesignKit.Spacing.Primitive.s16)
            VStack(spacing: DesignKit.Spacing.Primitive.s2) {
                ForEach(terms, id: \.self) { term in
                    Button {
                        onSelect(term)
                    } label: {
                        HStack {
                            Label(term, systemImage: "magnifyingglass")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(DesignKit.Spacing.Primitive.s16)
                        .frame(maxWidth: .infinity)
                        .background(Color.cardBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Small icon + title header used by the empty-state sections.
private struct SearchSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.pixel12)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel(repository: AppContainer.live.repository))
}
