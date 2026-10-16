import Foundation
import SwiftData
import SwiftUI

/// Observable view model behind the pokedex grid.
///
/// Like every screen in the app, the view depends on this protocol rather
/// than the concrete class, so a stub can be injected. The
/// conforming type is a `@MainActor @Observable` class that views hold in
/// `@State`, so SwiftUI tracks exactly the properties each body reads.
@MainActor
protocol PokedexViewModelProtocol {
    /// All fetched Pokemon for the grid.
    var pokemon: [Pokemon] { get }
    /// `true` while fetching is in-flight.
    var isLoading: Bool { get }
    /// 0...1 progress during first-load API fetch.
    var loadingProgress: Double { get }
    /// `true` when the first-load fetch failed (usually no connection) and
    /// nothing is stored yet; the grid offers a retry.
    var loadFailed: Bool { get }
    /// Currently selected tab in the parent `TabView`.
    var selectedTab: Tabs { get set }
    /// Current pokedex grid layout (3 cols vs 4 cols).
    var grid: GridLayout { get set }
    /// Active sort applied to the pokemon array.
    var sortType: SortType { get set }
    /// Ascending or descending.
    var sortDirection: SortDirection { get set }

    /// Pokemon sorted by current sort settings.
    var sortedPokemon: [Pokemon] { get }
    /// Load all Pokemon: cache first, then network if needed.
    func requestPokemon() async
}

extension PokedexViewModelProtocol {
    /// Sort type projection that also resets `sortDirection` to the new
    /// type's default, so pickers can bind to it with a key path.
    var sortTypeResettingDirection: SortType {
        get { sortType }
        set {
            sortType = newValue
            sortDirection = newValue.defaultDirection
        }
    }
}

/// Concrete implementation of `PokedexViewModelProtocol`.
///
/// Reads `Pokemon` models through the main `ModelContext` handed in by the
/// view; the repository only writes to the store in the background and
/// reports progress, so no model objects cross actors.
@MainActor
@Observable
final class PokedexViewModel {
    private let repository: any PokedexImporting
    private let modelContext: ModelContext

    var pokemon: [Pokemon] = [] { didSet { recomputeSortedPokemon() } }
    var isLoading: Bool = false
    var loadingProgress: Double = 0
    var loadFailed = false
    var selectedTab: Tabs = .pokedex
    var grid: GridLayout = .three
    var sortType: SortType = .number { didSet { recomputeSortedPokemon() } }
    var sortDirection: SortDirection = .ascending { didSet { recomputeSortedPokemon() } }
    /// Cached derived collection, recomputed only when an input changes so
    /// views that read it don't re-sort on every body evaluation.
    private(set) var sortedPokemon: [Pokemon] = []

    init(modelContext: ModelContext, repository: any PokedexImporting) {
        self.repository = repository
        self.modelContext = modelContext
    }
}

// MARK: - PokedexViewModelProtocol

extension PokedexViewModel: PokedexViewModelProtocol {
    func requestPokemon() async {
        guard !isLoading else { return }

        // Fast path: the store is already populated from a previous launch.
        if let stored = fetchStoredPokemon(), !stored.isEmpty {
            pokemon = stored
            return
        }

        isLoading = true
        defer { isLoading = false }
        loadingProgress = 0
        loadFailed = false

        do {
            // Download, decode, and import all run in `PokedexRepository` off the
            // main actor; only throttled progress hops back here.
            try await repository.loadPokemonIfNeeded { [weak self] fraction in
                await self?.setProgress(fraction)
            }
            pokemon = fetchStoredPokemon() ?? []
        } catch {
            loadFailed = true
            #if DEBUG
            print("PokedexViewModel: fetch failed: \(error)")
            #endif
        }
    }
}

// MARK: - Private
private extension PokedexViewModel {
    func recomputeSortedPokemon() {
        sortedPokemon = pokemon.sorted(by: sortType.comparator(direction: sortDirection))
    }

    /// Read the persisted rows through the main context so the models the
    /// UI holds belong to the main actor.
    func fetchStoredPokemon() -> [Pokemon]? {
        try? modelContext.fetch(FetchDescriptor<Pokemon>(sortBy: [SortDescriptor(\.id)]))
    }

    func setProgress(_ fraction: Double) {
        loadingProgress = fraction
    }
}
