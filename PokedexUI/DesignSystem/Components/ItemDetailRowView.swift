import SwiftUI

/// Full item row for the detail screen with sprite, name, and effect text.
struct ItemDetailRowView: View {
    let item: ItemDetail

    var body: some View {
        let effect = item.prettyEffect
        HStack(alignment: effect.isEmpty ? .center : .top, spacing: DesignKit.Spacing.Primitive.s16) {
            SpriteImage(url: item.sprites?.default)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: DesignKit.Spacing.Primitive.s16) {
                Text(item.prettyName)
                if !effect.isEmpty {
                    Text(effect)
                        .foregroundStyle(.secondary)
                        .lineHeight(.loose)
                }
            }
        }
        .padding(DesignKit.Spacing.Primitive.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
    }
}
