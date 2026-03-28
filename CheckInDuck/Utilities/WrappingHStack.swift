import SwiftUI

struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = arrangeRows(maxWidth: maxWidth, subviews: subviews)

        let width = rows.map { row in
            row.frames.reduce(CGFloat.zero) { partial, frame in max(partial, frame.maxX) }
        }.max() ?? 0
        let height = rows.last.map { $0.maxY } ?? 0

        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = arrangeRows(maxWidth: bounds.width, subviews: subviews)

        for row in rows {
            for element in row.elements {
                let point = CGPoint(
                    x: bounds.minX + element.frame.minX,
                    y: bounds.minY + element.frame.minY
                )
                element.subview.place(
                    at: point,
                    proposal: ProposedViewSize(element.frame.size)
                )
            }
        }
    }

    private func arrangeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        guard !subviews.isEmpty else { return [] }

        let measured = subviews.map { subview in
            let size = subview.sizeThatFits(.unspecified)
            return Element(subview: subview, size: size, frame: .zero)
        }

        var rows: [Row] = []
        var currentElements: [Element] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        func flushRow() {
            guard !currentElements.isEmpty else { return }
            let maxY = currentY + rowHeight
            rows.append(Row(elements: currentElements, maxY: maxY))
            currentY = maxY + verticalSpacing
            currentElements = []
            currentX = 0
            rowHeight = 0
        }

        for var element in measured {
            let itemWidth = min(element.size.width, maxWidth)
            let itemSize = CGSize(width: itemWidth, height: element.size.height)
            let nextX = currentElements.isEmpty ? 0 : currentX + horizontalSpacing

            if nextX + itemSize.width > maxWidth, !currentElements.isEmpty {
                flushRow()
            }

            let originX = currentElements.isEmpty ? 0 : currentX + horizontalSpacing
            element.frame = CGRect(origin: CGPoint(x: originX, y: currentY), size: itemSize)
            currentElements.append(element)
            currentX = element.frame.maxX
            rowHeight = max(rowHeight, itemSize.height)
        }

        flushRow()
        return rows
    }
}

private struct Row {
    let elements: [Element]
    let maxY: CGFloat

    var frames: [CGRect] { elements.map(\.frame) }
}

private struct Element {
    let subview: LayoutSubview
    let size: CGSize
    var frame: CGRect
}
