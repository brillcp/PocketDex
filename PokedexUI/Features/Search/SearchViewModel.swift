import Foundation
import SwiftData

/// Search protocol owning the query string and filter logic against a Pokemon corpus.
@MainActor
protocol SearchViewModelProtocol {
    /// Curated chips shown in the search empty-state.
    static var suggestedTerms: [String] { get }

    /// The filtered list based on the current query.
    var filtered: [Pokemon] { get }
    /// The user's search input query. Setting it refreshes `filtered`.
    var query: String { get set }
    /// Most-recent submitted search terms, newest first.
    var recentSearches: [String] { get }
    /// Two random Pokemon sampled from the corpus; shown in empty-state.
    var suggestedPokemon: [Pokemon] { get }

    /// Replaces the backing corpus (called by SearchView when @Query updates).
    /// The search haystacks are built off the main actor.
    func updateCorpus(_ corpus: [Pokemon]) async
    /// Filters the list based on the query and updates `filtered`.
    func updateFilteredPokemon()
    /// Records the current `query` into `recentSearches`.
    func recordSearch()
    /// Wipes the recent searches list.
    func clearRecentSearches()
}

/// Concrete implementation of `SearchViewModelProtocol` fed from SearchView's `@Query`.
///
/// Building a haystack (name, types, abilities, habitat, ... normalized into
/// one string) for 1,000+ Pokémon is the expensive part, so the store does it
/// in the background and returns `Sendable` id/haystack pairs. This class
/// joins them back to the main-context models by id, and per-keystroke
/// filtering is then just substring checks on the main actor.
@MainActor
@Observable
final class SearchViewModel {
    private static let recentSearchesKey = "search.recentSearches"
    private static let maxRecentSearches = 8

    static let suggestedTerms = [
        "cave", "fire", "water", "psychic", "dragon",
        "forest", "sea", "mouse", "bird", "legendary",
        "electric bug", "ghost dark"
    ]

    /// Main-context models paired with their background-built haystack.
    private var index: [(pokemon: Pokemon, haystack: String)] = []
    private let repository: any PokedexSnapshotReading
    private let defaults: UserDefaults

    var filtered: [Pokemon] = []
    var query: String = "" { didSet { updateFilteredPokemon() } }
    var recentSearches: [String]
    var suggestedPokemon: [Pokemon] = []

    init(repository: any PokedexSnapshotReading, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
        self.recentSearches = defaults.stringArray(forKey: Self.recentSearchesKey) ?? []
    }
}

// MARK: - SearchViewModelProtocol

extension SearchViewModel: SearchViewModelProtocol {
    func updateCorpus(_ corpus: [Pokemon]) async {
        let entries = await repository.searchIndex()
        let byId = Dictionary(corpus.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        index = entries.compactMap { entry in
            byId[entry.id].map { ($0, entry.haystack) }
        }
        if suggestedPokemon.isEmpty && !corpus.isEmpty {
            suggestedPokemon = Array(corpus.shuffled().prefix(2))
        }
        if !query.isEmpty { updateFilteredPokemon() }
    }

    func updateFilteredPokemon() {
        let queryTerms = query
            .split(whereSeparator: \.isWhitespace)
            .map { $0.normalize }
            .filter { !$0.isEmpty }

        // Every term must match (AND), so "electric bug" narrows results.
        guard !queryTerms.isEmpty else {
            filtered = []
            return
        }

        filtered = index.compactMap { entry in
            queryTerms.allSatisfy { entry.haystack.contains($0) } ? entry.pokemon : nil
        }
    }

    func recordSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > Self.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Self.maxRecentSearches))
        }
        defaults.set(recentSearches, forKey: Self.recentSearchesKey)
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
        defaults.removeObject(forKey: Self.recentSearchesKey)
    }
}

