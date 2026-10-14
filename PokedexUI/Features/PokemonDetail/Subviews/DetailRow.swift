import SwiftUI

/// Circular glass icon button used for the action row above the sprite.
struct DetailButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24.0, height: 24.0)
                .padding(10)
        }
        .glassEffect(.clear.interactive(), in: Circle())
    }
}

/// Titled section with glass-effect card. Used for Data, Stats, and Evolution
/// sections in the detail view.
struct DetailSection<Content: View>: View {
    var title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading) {
            if let title {
                Text(title)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 32) {
                content()
            }
            .padding(24.0)
            .glassEffect(.clear, in: Rectangle())
        }
    }
}

/// Species genus, generation badge, and legendary/mythical tags.
struct SpeciesHeader: View {
    let genus: String?
    let generationLabel: String?
    let isLegendary: Bool
    let isMythical: Bool
    let textColor: Color

    var body: some View {
        HStack {
            if let genus {
                Text(genus)
                    .font(.pixel14)
            }
            Spacer()
            if let generationLabel {
                Chip(generationLabel, style: .custom(background: textColor.opacity(0.1), foreground: textColor))
            }
            if isLegendary { Chip("LEGENDARY", style: .primary) }
            if isMythical { Chip("MYTHICAL", style: .primary) }
        }
        .padding(.horizontal, 24)
    }
}

/// Generic "Label: value" row with fixed-width labels for alignment.
/// Use `.vertical` axis for stacked label/value layout (abilities, moves).
struct DetailRow: View {
    var title: String?
    let subtitle: String
    var axis: Axis = .horizontal

    var body: some View {
        switch axis {
        case .horizontal:
            HStack(alignment: .top, spacing: 16) {
                if let title {
                    Text(title)
                        .frame(width: 82, alignment: .leading)
                }
                Text(subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .vertical:
            VStack(alignment: .leading) {
                if let title {
                    Text(title)
                }
                Text(subtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Tappable type chips row for the detail view.
struct TypesRow: View {
    let typeNames: [String]
    let onSelectType: (String) -> Void

    @State private var tapTrigger = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("Types")
                .frame(width: 82, alignment: .leading)
            HStack {
                ForEach(typeNames, id: \.self) { type in
                    Button {
                        tapTrigger.toggle()
                        onSelectType(type)
                    } label: {
                        Chip.type(type)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapTrigger)
    }
}

/// Labelled gauge for base stats with abbreviated stat names.
struct DetailRowStat: View {
    let title: String
    let value: Int
    let textColor: Color

    private var abbreviatedTitle: String {
        switch title.lowercased() {
        case "special-attack":  return "SATK"
        case "attack":          return "ATK"
        case "hp":              return "HP"
        case "speed":           return "SPD"
        case "special-defense": return "SDEF"
        case "defense":         return "DEF"
        default:                return title.capitalized
        }
    }

    var body: some View {
        let maxValue = max(value, 100)
        let clampedValue = max(value, 0)
        let progress = Double(clampedValue) / Double(maxValue)

        HStack {
            Text(abbreviatedTitle)
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)
            Text("\(clampedValue)")
                .frame(width: 32)
            ProgressView(value: progress)
                .tint(textColor)
            Text("\(maxValue)")
                .frame(width: 32)
        }
    }
}
