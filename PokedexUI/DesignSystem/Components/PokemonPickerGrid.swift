import SwiftUI

/// A titled group of Pokémon in a `PokemonGrid`.
struct PokemonGridSection: Identifiable {
    let id: String
    var title: String?
    let pokemon: [Pokemon]
    /// Whether cells in this section show the picker's badge.
    var showsBadges = false

    /// A single untitled section, for plain grids.
    static func all(_ pokemon: [Pokemon]) -> PokemonGridSection {
        PokemonGridSection(id: "all", pokemon: pokemon)
    }
}

/// Generic Pokemon grid. Callers provide column layout and cell content
/// via `@ViewBuilder`. Handles only scrolling and layout; navigation,
/// search, and loading overlays are the caller's responsibility.
///
/// Rows are identified by Pokémon id, so re-sorting or filtering animates
/// cells to new positions instead of rebuilding them. One haptic trigger
/// for the whole grid (via a simultaneous tap gesture) avoids attaching
/// `.sensoryFeedback` to every cell.
struct PokemonGrid<Cell: View>: View {
    let sections: [PokemonGridSection]
    var grid: GridLayout = .three
    var contentPadding: EdgeInsets = .init()
    @ViewBuilder let cell: (Pokemon, PokemonGridSection) -> Cell

    @State private var tapTrigger = false

    /// A Pokémon in a section. Ids are scoped by section: a lazy grid needs
    /// them unique across all sections, and a Pokémon can be in two (a team
    /// member is also in its generation). They're the `ForEach` identity
    /// itself, not an extra `.id(_:)`, so cells keep a stable identity and
    /// zoom transitions can find their source cell.
    private struct Item: Identifiable {
        let section: String
        let pokemon: Pokemon
        var id: String { "\(section)-\(pokemon.id)" }
    }

    init(
        sections: [PokemonGridSection],
        grid: GridLayout = .three,
        contentPadding: EdgeInsets = .init(),
        @ViewBuilder cell: @escaping (Pokemon, PokemonGridSection) -> Cell
    ) {
        self.sections = sections
        self.grid = grid
        self.contentPadding = contentPadding
        self.cell = cell
    }

    init(
        pokemon: [Pokemon],
        grid: GridLayout = .three,
        contentPadding: EdgeInsets = .init(),
        @ViewBuilder cell: @escaping (Pokemon) -> Cell
    ) {
        self.init(sections: [.all(pokemon)], grid: grid, contentPadding: contentPadding) { pokemon, _ in
            cell(pokemon)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid.layout, spacing: grid.spacing) {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.pokemon.map { Item(section: section.id, pokemon: $0) }) { item in
                            cell(item.pokemon, section)
                                .simultaneousGesture(TapGesture().onEnded { tapTrigger.toggle() })
                        }
                    } header: {
                        if let title = section.title {
                            header(title)
                        }
                    }
                }
            }
            .padding(contentPadding)
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .sensoryFeedback(.impact(weight: .light), trigger: tapTrigger)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.pixel12)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignKit.Spacing.Primitive.s16)
            .padding(.top, DesignKit.Spacing.Primitive.s16)
            .padding(.bottom, DesignKit.Spacing.Primitive.s8)
    }
}

/// Searchable Pokemon grid used by the fighter picker, multiplayer fighter
/// picker, and my team. Wraps `PokemonGrid` with a toolbar search bar and
/// haystack-based filtering. Search filters every section; sections with no
/// matches are hidden.
///
/// Callers that manage their own search (e.g. SearchView) should use
/// `PokemonGrid` directly instead.
///
/// Unlike the Search tab, the haystacks here are built on the main actor on
/// first appear, as a one-time pass over the models already passed in
/// (later keystrokes only run substring checks against it).
struct PokemonPickerGrid: View {
    @Environment(\.featureFlags) private var featureFlags

    let sections: [PokemonGridSection]
    var namespace: Namespace.ID?
    /// Shown on the top-trailing corner of cells in sections with
    /// `showsBadges`.
    var badge: ((Pokemon) -> Chip?)?
    /// Adds the toolbar search field. Off for short lists like "My team".
    var isSearchable = true
    let onSelect: (Pokemon) -> Void

    @State private var searchText = ""
    @State private var haystacks: [Int: String] = [:]
    @State private var filteredSections: [PokemonGridSection]?

    init(
        sections: [PokemonGridSection],
        namespace: Namespace.ID? = nil,
        badge: ((Pokemon) -> Chip?)? = nil,
        isSearchable: Bool = true,
        onSelect: @escaping (Pokemon) -> Void
    ) {
        self.sections = sections
        self.namespace = namespace
        self.badge = badge
        self.isSearchable = isSearchable
        self.onSelect = onSelect
    }

    init(
        pokemon: [Pokemon],
        namespace: Namespace.ID? = nil,
        isSearchable: Bool = true,
        onSelect: @escaping (Pokemon) -> Void
    ) {
        self.init(sections: [.all(pokemon)], namespace: namespace, isSearchable: isSearchable, onSelect: onSelect)
    }

    var body: some View {
        PokemonGrid(sections: filteredSections ?? sections) { pokemon, section in
            Button {
                onSelect(pokemon)
            } label: {
                PokemonSpriteCard(pokemon: pokemon, hidesName: featureFlags.silhouetteEnabled)
                    .overlay(alignment: .topTrailing) {
                        if section.showsBadges, let chip = badge?(pokemon) {
                            chip.padding(DesignKit.Spacing.Primitive.s6)
                        }
                    }
                    .applyTransitionSource(id: pokemon.id, namespace: namespace)
            }
            .buttonStyle(.plain)
        }
        .modifier(PickerSearch(isEnabled: isSearchable, text: $searchText))
        .onAppear(perform: buildIndex)
        .onChange(of: searchText, updateFilteredSections)
        // New rows (team edits, the first-launch import) while a search is
        // showing: index them and re-filter, so results aren't stale.
        .onChange(of: sections.map { $0.pokemon.map(\.id) }) {
            buildIndex()
            updateFilteredSections()
        }
    }
}

// MARK: - Private
private extension PokemonPickerGrid {
    func updateFilteredSections() {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map { $0.normalize }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            filteredSections = nil
            return
        }
        filteredSections = sections.compactMap { section in
            let matches = section.pokemon.filter { pokemon in
                let haystack = haystacks[pokemon.id] ?? Pokemon.searchHaystack(for: pokemon)
                return terms.allSatisfy { haystack.contains($0) }
            }
            guard !matches.isEmpty else { return nil }
            return PokemonGridSection(
                id: section.id, title: section.title, pokemon: matches, showsBadges: section.showsBadges
            )
        }
    }

    /// Indexes any Pokémon not indexed yet.
    func buildIndex() {
        var built = haystacks
        for pokemon in sections.flatMap(\.pokemon) where built[pokemon.id] == nil {
            built[pokemon.id] = Pokemon.searchHaystack(for: pokemon)
        }
        if built.count != haystacks.count { haystacks = built }
    }
}

/// The picker's toolbar search field, when enabled.
private struct PickerSearch: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .searchable(text: $text, placement: .toolbarPrincipal)
                .scrollDismissesKeyboard(.immediately)
        } else {
            content
        }
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
