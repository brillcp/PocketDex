import SwiftUI

/// Scrollable battle log pinned to the latest event, with a fade/shrink
/// effect on the top row so the player can scroll back through history.
struct BattleLogFeed: View {
    let log: [BattleLogEntry]

    var body: some View {
        // Captured as values: the `visualEffect` closure runs off the main actor.
        let fadeDistance = Layout.fadeDistance
        let minScale = Layout.minScale
        // Bottom-anchored, so new entries keep the latest line in view
        // without a ScrollViewReader.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Layout.lineSpacing) {
                ForEach(log) { entry in
                    Text(entry.attributed)
                        .font(.pixel12)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: Layout.lineHeight, alignment: .leading)
                        .visualEffect { content, proxy in
                            let frame = proxy.frame(in: .scrollView(axis: .vertical))
                            let progress = max(0, min(1, frame.minY / fadeDistance))
                            return content
                                .opacity(progress)
                                .scaleEffect(minScale + (1 - minScale) * progress, anchor: .top)
                        }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(height: Layout.visibleHeight)
        .defaultScrollAnchor(.bottom)
        .animation(.easeOut, value: log.count)
    }
}

/// Fixed metrics for the feed. Every row has the same height, so the
/// visible window is exactly `lineCount` lines and the log area doesn't
/// resize as entries arrive.
private enum Layout {
    static let lineCount = 6
    static let lineHeight: CGFloat = 16
    static let lineSpacing: CGFloat = 4
    static let fadeDistance: CGFloat = 22
    static let minScale: CGFloat = 0.96

    static var visibleHeight: CGFloat {
        lineHeight * CGFloat(lineCount) + lineSpacing * CGFloat(lineCount + 1)
    }
}
