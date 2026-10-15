import SwiftUI
import PokeBattleKit

/// Single move cell shared by the battle grid and the loadout picker.
/// `Equatable` so callers can apply `.equatable()` and skip the body when
/// the move, mode, and effectiveness are unchanged.
struct MoveCell: View, Equatable {
    let move: Move
    let mode: Mode
    let effectiveness: Double?

    init(move: Move, mode: Mode, effectiveness: Double? = nil) {
        self.move = move
        self.mode = mode
        self.effectiveness = effectiveness
    }

    /// `.battle` shows PP; `.loadout` shows power/accuracy and selection.
    enum Mode: Equatable {
        case battle
        case loadout(selected: Bool)
    }

    var body: some View {
        HStack(spacing: DesignKit.Spacing.Primitive.s12) {
            if case .loadout(let selected) = mode, selected {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .foregroundStyle(.white)
                    .frame(width: DesignKit.Spacing.Primitive.s16, height: DesignKit.Spacing.Primitive.s16)
            }
            VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s4) {
                HStack {
                    header
                    if let effectiveness, (move.power ?? 0) > 0 {
                        Spacer()
                        Chip(TypeEffectiveness.label(for: effectiveness), style: TypeEffectiveness.chipStyle(for: effectiveness))
                    }
                }
                footer
            }
        }
        .padding(DesignKit.Spacing.Primitive.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay { overlay }
    }
}

// MARK: - Private
private extension MoveCell {
    var header: some View {
        HStack {
            Text(move.displayName)
                .font(.pixel12)
                .lineLimit(1)
        }
        .frame(height: DesignKit.Spacing.Primitive.s16)
    }

    var footer: some View {
        HStack(spacing: DesignKit.Spacing.Primitive.s12) {
            Chip.type(move.typeName)
            switch mode {
            case .battle:
                if let pp = move.pp {
                    Text("PP \(pp)")
                        .font(.pixel12)
                }
            case .loadout:
                VStack(alignment: .leading) {
                    Text("PWR")
                    Text(move.power.map { $0.formatted() } ?? "-")
                }
                VStack(alignment: .leading) {
                    Text("ACC")
                    Text(move.accuracy.map { (Double($0) / 100).formatted(.pixelPercent()) } ?? "-")
                }
            }
        }
        .font(.pixel9)
        .foregroundStyle(.secondary)
    }

    var background: AnyShapeStyle {
        switch mode {
        case .battle:
            return AnyShapeStyle(Color.cardBackground)
        case .loadout(let selected):
            let accent = Color.pokedexRed
            return AnyShapeStyle(selected ? accent.opacity(0.4) : Color.cardBackground)
        }
    }

    @ViewBuilder
    var overlay: some View {
        switch mode {
        case .battle:
            EmptyView()
        case .loadout(let selected):
            let accent = Color.pokedexRed
            Rectangle()
                .stroke(selected ? accent.opacity(0.8) : .clear, lineWidth: 1)
        }
    }
}
