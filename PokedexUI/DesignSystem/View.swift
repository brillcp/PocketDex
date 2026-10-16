import SwiftUI

extension View {
    /// Shared navigation-bar look: pixel-font inline title, opaque tinted
    /// bar, and a full-bleed background. Pass `background: nil` for screens
    /// that draw their own (e.g. the detail view's mesh gradient).
    ///
    /// Like `Text`, a string literal title is a localization key, and a
    /// `String` value (a name from the data) is shown as is.
    func applyPokedexStyling(
        title: LocalizedStringKey,
        navColor: Color = Color.pokedexRed,
        titleColor: Color = .white,
        background: Color? = Color.darkGrey
    ) -> some View {
        pokedexStyling(Text(title), navColor: navColor, titleColor: titleColor, background: background)
    }

    @_disfavoredOverload
    func applyPokedexStyling<S: StringProtocol>(
        title: S,
        navColor: Color = Color.pokedexRed,
        titleColor: Color = .white,
        background: Color? = Color.darkGrey
    ) -> some View {
        pokedexStyling(Text(title), navColor: navColor, titleColor: titleColor, background: background)
    }
}

// MARK: - Private
private extension View {
    func pokedexStyling(_ title: Text, navColor: Color, titleColor: Color, background: Color?) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    title
                        .font(.pixel18)
                        .foregroundStyle(titleColor)
                }
            }
            .toolbarBackground(navColor, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .background { background?.ignoresSafeArea() }
    }
}
