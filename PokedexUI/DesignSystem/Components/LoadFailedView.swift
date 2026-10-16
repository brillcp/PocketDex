import SwiftUI

/// Empty state for a first load that failed (usually no connection), with a
/// button to try again.
struct LoadFailedView: View {
    let title: LocalizedStringKey
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "wifi.exclamationmark")
                .font(.pixel14)
        } description: {
            Text("loadFailed.description")
                .font(.pixel12)
        } actions: {
            Button("loadFailed.retry", action: retry)
                .font(.pixel14)
                .buttonStyle(.glass)
        }
        .foregroundStyle(.white)
    }
}
