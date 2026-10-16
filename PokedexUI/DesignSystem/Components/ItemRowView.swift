import SwiftUI

/// Single row in the items tab with sprite, name, and navigation chevron.
struct ItemRowView: View {
    let item: ItemData

    var body: some View {
        HStack(spacing: DesignKit.Spacing.Primitive.s16) {
            SpriteImage(url: item.icon)
                .frame(width: 38)
            Text(item.prettyTitle)
            Spacer()
            Text(">")
                .foregroundStyle(.secondary)
        }
        .padding(DesignKit.Spacing.Primitive.s16)
        .background(Color.cardBackground)
    }
}
