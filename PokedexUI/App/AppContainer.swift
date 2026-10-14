import SwiftUI
import SwiftData

/// Process-wide composition root for dependency injection. Constructed
/// once at app launch and exposed via `Environment(\.container)`. The
/// `static let live` instance wires real implementations; tests and
/// previews can call `init(...)` directly and pass mocks per parameter
/// without restating the others.
///
/// Owns the shared `ModelContainer`: the UI reads through its main
/// context (`.modelContainer(...)` / `@Query`) while the
/// background `PokedexStore` writes through its own context on the same container.
/// `Sendable`: every member is an immutable reference to a Sendable service
/// (actors, Sendable protocols, the main-actor `MultipeerService`), so the
/// container can be the nonisolated `@Entry` default.
final class AppContainer: Sendable {
    let modelContainer: ModelContainer

    let repository:         PokedexRepositoryProtocol
    let evolutionService:   EvolutionServiceProtocol
    let spriteLoader:       SpriteLoading
    let imageColorAnalyzer: ImageColorAnalyzing
    let audioPlayer:        AudioPlaying
    let battleAI:           BattleAIServiceProtocol
    let multipeerService:   MultipeerService

    init(
        modelContainer:     ModelContainer           = AppContainer.makeModelContainer(),
        repository:         PokedexRepositoryProtocol? = nil,
        evolutionService:   EvolutionService?        = nil,
        spriteLoader:       SpriteLoading            = SpriteLoader(),
        imageColorAnalyzer: ImageColorAnalyzing      = ImageColorAnalyzer(),
        audioPlayer:        AudioPlaying             = AudioPlayer(),
        battleAI:           BattleAIServiceProtocol  = BattleAIService(),
        multipeerService:   MultipeerService         = MultipeerService()
    ) {
        let evolutionService = evolutionService ?? EvolutionService(modelContainer: modelContainer)
        self.modelContainer     = modelContainer
        self.repository         = repository ?? PokedexRepository(
            modelContainer: modelContainer,
            evolutionService: evolutionService
        )
        self.evolutionService   = evolutionService
        self.spriteLoader       = spriteLoader
        self.imageColorAnalyzer = imageColorAnalyzer
        self.audioPlayer        = audioPlayer
        self.battleAI           = battleAI
        self.multipeerService   = multipeerService
    }

    /// Production composition. Reached via `Environment(\.container)`;
    /// also used by Previews to keep the tree close to the live wiring.
    static let live = AppContainer()
}

extension AppContainer {
    static func makeModelContainer(inMemory: Bool = false) -> ModelContainer {
        do {
            return try ModelContainer(
                for: Pokemon.self, ItemData.self, EvolutionChainEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("Failed to create the SwiftData container: \(error)")
        }
    }
}
