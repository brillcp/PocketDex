import SwiftData

/// One individual PokeAPI item with sprite, category, and effect list.
@Model
final class ItemDetail {
    @Attribute(.unique) var id: Int
    var name: String
    var prettyName: String = ""
    var sprites: ItemSprite?
    var category: APIItem
    @Relationship var effect: [Effect]

    init(id: Int, name: String, sprites: ItemSprite?, category: APIItem, effect: [Effect]) {
        self.id = id
        self.name = name
        self.prettyName = name.pretty
        self.sprites = sprites
        self.category = category
        self.effect = effect
    }
}

extension ItemDetail {
    convenience init(dto: ItemDetailDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            sprites: dto.sprites.map { ItemSprite(default: $0.default) },
            category: APIItem(dto.category),
            effect: dto.englishEffects.map(Effect.init(effect:))
        )
    }
}

extension ItemDetail {
    var prettyEffect: String {
        effect.first?.prettyEffect ?? ""
    }
}

/// Item category bucket holding a title and list of `ItemDetail`s.
@Model
final class ItemData {
    var title: String
    var prettyTitle: String = ""
    var items: [ItemDetail]

    init(title: String, items: [ItemDetail]) {
        self.title = title
        self.prettyTitle = title.pretty
        self.items = items
    }
}

extension ItemData {
    var icon: String? {
        items.first?.sprites?.default
    }
}

/// Optional default sprite URL for an item.
@Model
final class ItemSprite {
    var `default`: String?

    init(default: String?) {
        self.default = `default`
    }
}

/// Short-form effect text for an item.
@Model
final class Effect {
    var effect: String
    var prettyEffect: String = ""

    @Relationship(inverse: \ItemDetail.effect)
    var itemDetail: ItemDetail?

    init(effect: String) {
        self.effect = effect
        self.prettyEffect = effect.pretty
    }
}

extension ItemDetail {
    static var common: ItemDetail {
        .init(
            id: 0,
            name: "Item",
            sprites: .init(
                default: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/honey.png"
            ),
            category: .init(name: "category", url: ""),
            effect: [
                .init(effect: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat")
            ]
        )
    }
}
