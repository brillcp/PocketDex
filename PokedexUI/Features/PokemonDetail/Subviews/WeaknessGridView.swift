import SwiftUI
import PokeBattleKit

/// Bucketed type-effectiveness grids showing both defensive (weaknesses/resistances)
/// and offensive (strengths) matchups. Type chips are tappable to browse
/// all Pokemon of that type.
struct WeaknessGridView: View {
    let typeNames: [String]
    let textColor: Color
    let onSelectType: (String) -> Void

    @State private var tapTrigger = false

    var body: some View {
        // The type chart loads asynchronously at app launch; render nothing
        // until it's available rather than showing a wrong matchup.
        if PokeBattleKit.isInitialized {
            VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s24) {
                matchupSection(title: "Strengths", buckets: offensiveBuckets)
                matchupSection(title: "Weaknesses", buckets: defensiveBuckets)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Private
private extension WeaknessGridView {

    // MARK: Defensive (what hits this Pokemon)

    /// Combined multiplier against all of this Pokémon's types (so dual
    /// types can produce x4 or x0.25). Neutral matchups are omitted.
    var defensiveBuckets: [(label: String, types: [String])] {
        let defenders = typeNames
        // Empty until the battle catalogue has loaded (first launch).
        guard let chart = PokeBattleKit.typeChartIfLoaded else { return [] }

        var rows: [Double: [String]] = [:]
        for (attackerName, _) in chart.attackers {
            let m = chart.multiplier(attacking: attackerName, defenders: defenders)
            guard m != 1.0 else { continue }
            rows[m, default: []].append(attackerName)
        }
        let order: [(Double, String)] = [(4, "x4"), (2, "x2"), (0.5, "x0.5"), (0.25, "x0.25"), (0, "x0")]
        return order.compactMap { mult, label in
            guard let names = rows[mult], !names.isEmpty else { return nil }
            return (label, names.sorted())
        }
    }

    // MARK: Offensive (what this Pokemon hits)

    /// Uses the best multiplier across this Pokémon's own types, since it
    /// can pick whichever STAB type suits the defender.
    var offensiveBuckets: [(label: String, types: [String])] {
        let attackers = typeNames
        guard !attackers.isEmpty, let chart = PokeBattleKit.typeChartIfLoaded else { return [] }

        var rows: [Double: [String]] = [:]
        for (defenderName, _) in chart.attackers {
            let best = attackers
                .map { chart.multiplier(attacking: $0, defenders: [defenderName]) }
                .max() ?? 1.0
            guard best != 1.0 else { continue }
            rows[best, default: []].append(defenderName)
        }
        let order: [(Double, String)] = [(4, "x4"), (2, "x2"), (0.5, "x0.5"), (0.25, "x0.25"), (0, "x0")]
        return order.compactMap { mult, label in
            guard let names = rows[mult], !names.isEmpty else { return nil }
            return (label, names.sorted())
        }
    }

    // MARK: Shared UI

    @ViewBuilder
    func matchupSection(title: String, buckets: [(label: String, types: [String])]) -> some View {
        if !buckets.isEmpty {
            VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s8) {
                Text(title)
                ForEach(buckets, id: \.label) { row in
                    HStack(alignment: .top, spacing: DesignKit.Spacing.Primitive.s12) {
                        Text(row.label)
                            .frame(width: 48, alignment: .leading)
                            .foregroundStyle(textColor)
                        typeChips(row.types)
                    }
                }
            }
        }
    }

    func typeChips(_ types: [String]) -> some View {
        FlowLayout(spacing: DesignKit.Spacing.Primitive.s6) {
            ForEach(types, id: \.self) { type in
                Button {
                    tapTrigger.toggle()
                    onSelectType(type)
                } label: {
                    Chip.type(type)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapTrigger)
    }
}
