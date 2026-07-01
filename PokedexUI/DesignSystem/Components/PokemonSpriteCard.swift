import SwiftUI

/// Sprite-over-name grid cell used in search, my team, type lists, and
/// picker grids. Reads the silhouette feature flag from the environment
/// itself, so callers never pass it; equality is by Pokémon id, so a cell
/// only re-renders when it shows a different Pokémon (or the flag changes).
struct PokemonSpriteCard: View {
    @Environment(\.featureFlags) private var featureFlags

    let pokemon: Pokemon

    var body: some View {
        VStack(spacing: DesignKit.Spacing.Primitive.s12) {
            SpriteImage(url: pokemon.frontSprite)
                .frame(height: 92)
            if !featureFlags.silhouetteEnabled {
                Text(pokemon.name)
                    .font(.pixel12)
                    .lineLimit(1)
            }
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

extension PokemonSpriteCard: Equatable {
    static func == (lhs: borrowing PokemonSpriteCard, rhs: borrowing PokemonSpriteCard) -> Bool {
        lhs.pokemon.id == rhs.pokemon.id
    }
}
