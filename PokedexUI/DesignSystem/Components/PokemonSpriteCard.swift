import SwiftUI

/// Sprite-over-name grid cell used in search, bookmarks, type lists, and
/// opponent picker grids. Reads only the passed-in model, so a cell
/// re-renders only when that Pokémon's own properties change.
struct PokemonSpriteCard: View, Equatable {
    let pokemon: Pokemon

    var body: some View {
        VStack(spacing: DesignKit.Spacing.Primitive.s12) {
            SpriteImage(url: pokemon.frontSprite)
                .frame(height: 92)
            Text(pokemon.name)
                .font(.pixel12)
                .lineLimit(1)
            HStack {
                ForEach(pokemon.types) { type in
                    Chip.type(type)
                }
            }
        }
        .padding(DesignKit.Spacing.Primitive.s16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .foregroundStyle(.white)
    }
}
