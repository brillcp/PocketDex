import SwiftUI
import PokeBattleKit

/// The player's chosen AI difficulty, persisted in `UserDefaults`.
///
/// Read it with `@AppStorage(BattleDifficulty.key) var difficulty = BattleDifficulty.defaultValue`;
/// every screen that asks the AI for a decision passes it along, so a
/// change applies from the next decision on.
enum BattleDifficulty {
    static let key = "battleDifficulty"
    static let defaultValue: Difficulty = .fair
}

extension Difficulty {
    var title: LocalizedStringKey {
        switch self {
        case .easy: "difficulty.easy"
        case .fair: "difficulty.fair"
        case .hard: "difficulty.hard"
        }
    }

    /// One-line explanation shown under each option in the menu.
    var summary: LocalizedStringKey {
        switch self {
        case .easy: "difficulty.easy.summary"
        case .fair: "difficulty.fair.summary"
        case .hard: "difficulty.hard.summary"
        }
    }
}

/// Gear button that opens a menu for picking the AI difficulty.
struct DifficultyMenu: View {
    @AppStorage(BattleDifficulty.key) private var difficulty = BattleDifficulty.defaultValue

    var body: some View {
        Menu {
            Text("difficulty.title")
            Divider()
            Picker("difficulty.title", selection: $difficulty) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    // A second Text becomes the menu item's subtitle.
                    VStack {
                        Text(level.title)
                        Text(level.summary)
                    }
                    .tag(level)
                }
            }
        } label: {
            Label("difficulty.menu", systemImage: "gearshape.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: DesignKit.Spacing.Primitive.s40, height: DesignKit.Spacing.Primitive.s40)
        }
        .menuOrder(.fixed)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}
