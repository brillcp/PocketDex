import SwiftUI
import SwiftData

/// Search tab backed by its own SwiftData `@Query` against the full corpus.
struct SearchView<ViewModel: SearchViewModelProtocol>: View {
    @FocusState private var isSearchFocused: Bool
    @Namespace private var namespace
    @Environment(\.container) private var container
    @Environment(\.modelContext) private var modelContext
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
                            PokemonSpriteCard(pokemon: pokemon)
                                .applyTransitionSource(id: pokemon.id, namespace: namespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .font(.pixel14)
            .searchable(text: $viewModel.query)
            .searchFocused($isSearchFocused)
            .onSubmit(of: .search, viewModel.recordSearch)
            .task(id: corpus) {
                await viewModel.updateCorpus(corpus)
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: isSearchFocused) { old, new in
                guard old, !new, !viewModel.query.isEmpty else { return }
                viewModel.recordSearch()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.query)
            .applyPokedexStyling(title: Tabs.search.title)
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

// MARK: - Private
private extension SearchView {
    var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24.0) {
                if !viewModel.suggestedPokemon.isEmpty {
                    SuggestedPokemonSection(pokemon: viewModel.suggestedPokemon, namespace: namespace)
                }
                SuggestedTermsSection(terms: ViewModel.suggestedTerms, onSelect: selectSuggestedTerm)
                if !viewModel.recentSearches.isEmpty {
                    RecentSearchesSection(
                        terms: viewModel.recentSearches,
                        onSelect: { viewModel.query = $0 },
                        onClear: viewModel.clearRecentSearches
                    )
                } else {
                    Text("Search Pokemon, types, habitats or abilities")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, 80.0)
                        .padding(.horizontal)
                        .lineHeight(.loose)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(for: Pokemon.self) { pokemon in
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
        VStack(alignment: .leading, spacing: 8.0) {
            SearchSectionHeader(title: "Try searching for", systemImage: "magnifyingglass")
            FlowLayout(spacing: 6.0) {
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
        .padding(.horizontal)
    }
}

/// Random suggested Pokemon cards shown in the empty state.
private struct SuggestedPokemonSection: View {
    let pokemon: [Pokemon]
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            SearchSectionHeader(title: "Suggested", systemImage: "sparkles.2")
                .padding(.horizontal)
            LazyVGrid(columns: GridLayout.two.layout, spacing: GridLayout.two.spacing) {
                ForEach(pokemon, id: \.id) { pokemon in
                    NavigationLink(value: pokemon) {
                        PokemonSpriteCard(pokemon: pokemon)
                            .matchedTransitionSource(id: pokemon.id, in: namespace)
                    }
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
        VStack(alignment: .leading, spacing: 8.0) {
            HStack {
                SearchSectionHeader(title: "Recent", systemImage: "clock.arrow.circlepath")
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "trash.fill")
                        .font(.pixel16)
                        .foregroundStyle(Color.pokedexRed)
                }
            }
            .padding(.horizontal)
            VStack(spacing: 2.0) {
                ForEach(terms, id: \.self) { term in
                    Button {
                        onSelect(term)
                    } label: {
                        HStack {
                            Label(term, systemImage: "magnifyingglass")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding()
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
    let title: LocalizedStringResource
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
