import SwiftUI

/// Wrapping horizontal layout where rows break when available width is exceeded.
/// Subviews are measured at their ideal size (chips don't stretch); rows are
/// recomputed in both passes since the layout keeps no cache.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height + (total > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in 0..<row.count {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }
}

// MARK: - Private
private extension FlowLayout {
    struct Row {
        var count: Int
        var height: CGFloat
    }

    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row(count: 0, height: 0)
        var x: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && currentRow.count > 0 {
                rows.append(currentRow)
                currentRow = Row(count: 0, height: 0)
                x = 0
            }
            currentRow.count += 1
            currentRow.height = max(currentRow.height, size.height)
            x += size.width + spacing
        }
        if currentRow.count > 0 {
            rows.append(currentRow)
        }
        return rows
    }
}
