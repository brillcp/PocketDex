import SwiftUI

extension View {
    func applyPokedexStyling(
        title: String,
        navColor: Color = Color.pokedexRed,
        titleColor: Color = .white,
        background: Color? = Color.darkGrey
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.pixel18)
                        .foregroundStyle(titleColor)
                }
            }
            .toolbarBackground(navColor, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .background { background?.ignoresSafeArea() }
    }
}
