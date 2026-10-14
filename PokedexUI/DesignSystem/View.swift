import SwiftUI

extension View {
    /// Localized title variant; string literals and interpolations resolve here.
    func applyPokedexStyling(
        title: LocalizedStringResource,
        navColor: Color = Color.pokedexRed,
        titleColor: Color = .white,
        background: Color? = Color.darkGrey
    ) -> some View {
        pokedexStyling(title: Text(title), navColor: navColor, titleColor: titleColor, background: background)
    }

    /// Verbatim title variant for runtime strings (e.g. API-provided names).
    func applyPokedexStyling<S: StringProtocol>(
        title: S,
        navColor: Color = Color.pokedexRed,
        titleColor: Color = .white,
        background: Color? = Color.darkGrey
    ) -> some View {
        pokedexStyling(title: Text(title), navColor: navColor, titleColor: titleColor, background: background)
    }

    private func pokedexStyling(
        title: Text,
        navColor: Color,
        titleColor: Color,
        background: Color?
    ) -> some View {
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
