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
    var title: String {
        switch self {
        case .easy: "Easy"
        case .fair: "Fair"
        case .hard: "Hard"
        }
    }

    /// One-line explanation shown under each option in the menu.
    var summary: String {
        switch self {
        case .easy: "The opponent holds back"
        case .fair: "An even fight"
        case .hard: "The opponent always plays its best move"
        }
    }
}

/// Gear button that opens a menu for picking the AI difficulty.
struct DifficultyMenu: View {
    @AppStorage(BattleDifficulty.key) private var difficulty = BattleDifficulty.defaultValue

    var body: some View {
        Menu {
            Text("Difficulty")
            Divider()
            Picker("Difficulty", selection: $difficulty) {
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
            Label("Settings", systemImage: "gearshape.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: DesignKit.Spacing.Primitive.s44, height: DesignKit.Spacing.Primitive.s44)
        }
        .menuOrder(.fixed)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Difficulty: \(difficulty.title)")
    }
}
