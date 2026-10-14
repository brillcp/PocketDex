import SwiftUI

/// Full-width primary action button with pixel font and red glass tint.
/// While `isLoading` it swaps the icon for a spinner, shows `loadingTitle`,
/// and ignores taps.
struct PrimaryCapsuleButton: View {
    let icon: String
    let title: String
    var loadingTitle: String = "Thinking"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @State private var tapTrigger = false

    var body: some View {
        Button {
            tapTrigger.toggle()
            action()
        } label: {
            HStack(spacing: DesignKit.Spacing.Primitive.s8) {
                if isLoading {
                    PixelSpinner(color: .white)
                } else {
                    Image(systemName: icon)
                }
                Text(isLoading ? loadingTitle : title)
            }
            .font(.pixel16)
            .frame(height: 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignKit.Spacing.Primitive.s16)
            .foregroundStyle(.white)
        }
        .glassEffect(.regular.tint(.pokedexRed.opacity(0.8)).interactive())
        .disabled(!isEnabled || isLoading)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapTrigger)
    }
}

/// Compact secondary action with clear glass and a caller-supplied tint,
/// for use over colored backgrounds (e.g. "Battle" on the detail screen,
/// tinted to match the sprite-derived text color). No loading state or
/// haptic, unlike `PrimaryCapsuleButton`.
struct SecondaryCapsuleButton: View {
    let icon: String
    let title: String
    let color: Color
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.pixel14)
                .padding(.vertical, DesignKit.Spacing.Primitive.s12)
                .padding(.horizontal, DesignKit.Spacing.Primitive.s16)
                .foregroundStyle(color)
        }
        .glassEffect(.clear.interactive())
        .disabled(!isEnabled)
    }
}
