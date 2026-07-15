import Foundation

public protocol LayoutCalculating: Sendable {
    func layout(
        windows: [WindowSnapshot],
        displays: [DisplaySnapshot],
        spacing: Double
    ) -> LayoutResult
}

public struct LayoutEngine: LayoutCalculating, Sendable {
    public init() {}

    public func layout(
        windows: [WindowSnapshot],
        displays: [DisplaySnapshot],
        spacing: Double
    ) -> LayoutResult {
        let spacing = max(0, spacing)
        let displayByID = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0) })
        let inputOrder = Dictionary(
            uniqueKeysWithValues: windows.enumerated().map { ($0.element.token, $0.offset) }
        )
        var placements: [Placement] = []
        var skipped: [WindowToken: SkipReason] = [:]

        for window in windows where displayByID[window.displayID] == nil {
            skipped[window.token] = .insufficientSpace
        }

        for display in displays.sorted(by: Self.displaySort) {
            let available = display.visibleFrame.insetBy(dx: spacing, dy: spacing)
            let group = windows
                .filter { $0.displayID == display.id }
                .sorted(by: Self.windowSort)

            guard !available.isEmpty else {
                for window in group { skipped[window.token] = .insufficientSpace }
                continue
            }

            var fixedPlacements: [Placement] = []
            for window in group where !window.isResizable {
                let placement = Placement(token: window.token, frame: window.frame)
                if available.contains(window.frame)
                    && Self.hasRequiredSpacing(placement, from: fixedPlacements, spacing: spacing) {
                    fixedPlacements.append(placement)
                } else {
                    skipped[window.token] = .insufficientSpace
                }
            }

            var freeRectangles = [available]
            for fixed in fixedPlacements {
                freeRectangles = freeRectangles.flatMap {
                    Self.subtract($0, obstacle: fixed.frame, spacing: spacing)
                }
            }
            freeRectangles = freeRectangles
                .filter { !$0.isEmpty }
                .sorted(by: Self.freeRectangleSort)

            var remaining = group.filter { $0.isResizable }
            var movablePlacements: [Placement] = []

            for freeRectangle in freeRectangles where !remaining.isEmpty {
                var selected: Candidate?
                var selectedCount = 0

                for count in stride(from: remaining.count, through: 1, by: -1) {
                    let prefix = Array(remaining.prefix(count))
                    if let candidate = bestRows(
                        windows: prefix,
                        in: freeRectangle,
                        spacing: spacing
                    ) {
                        selected = candidate
                        selectedCount = count
                        break
                    }
                }

                if let selected {
                    movablePlacements.append(contentsOf: selected.placements)
                    remaining.removeFirst(selectedCount)
                }
            }

            for window in remaining {
                skipped[window.token] = .insufficientSpace
            }

            placements.append(contentsOf: fixedPlacements)
            placements.append(contentsOf: movablePlacements)
        }

        placements.sort {
            let first = inputOrder[$0.token] ?? .max
            let second = inputOrder[$1.token] ?? .max
            return first == second ? $0.token.windowID < $1.token.windowID : first < second
        }
        return LayoutResult(placements: placements, skipped: skipped)
    }
}

private extension LayoutEngine {
    struct Candidate {
        let placements: [Placement]
        let rowCounts: [Int]
        let score: Double
    }

    static func displaySort(_ first: DisplaySnapshot, _ second: DisplaySnapshot) -> Bool {
        if first.visibleFrame.minX != second.visibleFrame.minX {
            return first.visibleFrame.minX < second.visibleFrame.minX
        }
        if first.visibleFrame.minY != second.visibleFrame.minY {
            return first.visibleFrame.minY < second.visibleFrame.minY
        }
        return first.id < second.id
    }

    static func windowSort(_ first: WindowSnapshot, _ second: WindowSnapshot) -> Bool {
        if first.frame.minY != second.frame.minY { return first.frame.minY < second.frame.minY }
        if first.frame.minX != second.frame.minX { return first.frame.minX < second.frame.minX }
        return first.token.windowID < second.token.windowID
    }

    static func freeRectangleSort(_ first: Rect, _ second: Rect) -> Bool {
        if first.area != second.area { return first.area > second.area }
        if first.minY != second.minY { return first.minY < second.minY }
        return first.minX < second.minX
    }

    static func hasRequiredSpacing(
        _ placement: Placement,
        from existing: [Placement],
        spacing: Double
    ) -> Bool {
        existing.allSatisfy {
            placement.frame.expanded(by: spacing / 2)
                .intersection($0.frame.expanded(by: spacing / 2))
                .isEmpty
        }
    }

    static func subtract(_ rectangle: Rect, obstacle: Rect, spacing: Double) -> [Rect] {
        let overlap = rectangle.intersection(obstacle)
        guard !overlap.isEmpty else { return [rectangle] }

        var pieces: [Rect] = []
        let upperEdge = max(rectangle.minY, overlap.minY - spacing)
        if upperEdge > rectangle.minY {
            pieces.append(Rect(
                x: rectangle.minX,
                y: rectangle.minY,
                width: rectangle.width,
                height: upperEdge - rectangle.minY
            ))
        }
        let lowerEdge = min(rectangle.maxY, overlap.maxY + spacing)
        if lowerEdge < rectangle.maxY {
            pieces.append(Rect(
                x: rectangle.minX,
                y: lowerEdge,
                width: rectangle.width,
                height: rectangle.maxY - lowerEdge
            ))
        }
        let leftEdge = max(rectangle.minX, overlap.minX - spacing)
        if leftEdge > rectangle.minX {
            pieces.append(Rect(
                x: rectangle.minX,
                y: overlap.minY,
                width: leftEdge - rectangle.minX,
                height: overlap.height
            ))
        }
        let rightEdge = min(rectangle.maxX, overlap.maxX + spacing)
        if rightEdge < rectangle.maxX {
            pieces.append(Rect(
                x: rightEdge,
                y: overlap.minY,
                width: rectangle.maxX - rightEdge,
                height: overlap.height
            ))
        }
        return pieces.filter { !$0.isEmpty }
    }

    func bestRows(
        windows: [WindowSnapshot],
        in container: Rect,
        spacing: Double
    ) -> Candidate? {
        guard !windows.isEmpty else { return Candidate(placements: [], rowCounts: [], score: 0) }
        let maximumRows = min(
            windows.count,
            Int(ceil(sqrt(Double(windows.count)))) + 3
        )
        var best: Candidate?

        for rowCount in 1...maximumRows {
            for counts in Self.balancedCompositions(total: windows.count, parts: rowCount) {
                guard let candidate = candidate(
                    windows: windows,
                    rowCounts: counts,
                    container: container,
                    spacing: spacing
                ) else { continue }

                if Self.isBetter(candidate, than: best) {
                    best = candidate
                }
            }
        }
        return best
    }

    func candidate(
        windows: [WindowSnapshot],
        rowCounts: [Int],
        container: Rect,
        spacing: Double
    ) -> Candidate? {
        let usableHeight = container.height - spacing * Double(rowCounts.count - 1)
        guard usableHeight > 0 else { return nil }

        var offset = 0
        var naturalHeights: [Double] = []
        for count in rowCounts {
            let row = windows[offset..<(offset + count)]
            let usableWidth = container.width - spacing * Double(count - 1)
            let aspectSum = row.reduce(0) { $0 + $1.preferredAspectRatio }
            guard usableWidth > 0, aspectSum > 0 else { return nil }
            naturalHeights.append(usableWidth / aspectSum)
            offset += count
        }

        let naturalHeightTotal = naturalHeights.reduce(0, +)
        guard naturalHeightTotal > 0 else { return nil }
        let scale = usableHeight / naturalHeightTotal
        guard scale.isFinite, scale > 0 else { return nil }

        var placements: [Placement] = []
        var rowHeights: [Double] = []
        var windowIndex = 0
        var y = container.minY
        var movementCost = 0.0

        for (rowIndex, count) in rowCounts.enumerated() {
            let row = Array(windows[windowIndex..<(windowIndex + count)])
            let usableWidth = container.width - spacing * Double(count - 1)
            let aspectSum = row.reduce(0) { $0 + $1.preferredAspectRatio }
            let height = rowIndex == rowCounts.count - 1
                ? container.maxY - y
                : naturalHeights[rowIndex] * scale
            guard height > 0 else { return nil }
            rowHeights.append(height)

            var x = container.minX
            for (columnIndex, window) in row.enumerated() {
                let width = columnIndex == row.count - 1
                    ? container.maxX - x
                    : usableWidth * window.preferredAspectRatio / aspectSum
                guard width + 0.5 >= window.minimumWidth,
                      height + 0.5 >= window.minimumHeight else { return nil }

                let frame = Rect(x: x, y: y, width: width, height: height)
                guard container.contains(frame) else { return nil }
                placements.append(Placement(token: window.token, frame: frame))
                movementCost += sqrt(frame.distanceSquared(to: window.frame))
                x += width + spacing
            }
            y += height + spacing
            windowIndex += count
        }

        guard Self.placementsHaveSpacing(placements, spacing: spacing) else { return nil }
        let averageHeight = rowHeights.reduce(0, +) / Double(rowHeights.count)
        let variance = rowHeights.reduce(0) { partial, height in
            let difference = height - averageHeight
            return partial + difference * difference
        } / Double(rowHeights.count)
        let score = abs(log(scale)) * 1_000 + variance / 1_000 + movementCost / 10_000
        return Candidate(placements: placements, rowCounts: rowCounts, score: score)
    }

    static func balancedCompositions(total: Int, parts: Int) -> [[Int]] {
        guard total > 0, parts > 0, parts <= total else { return [] }
        let averageFloor = total / parts
        let averageCeiling = Int(ceil(Double(total) / Double(parts)))
        let lower = max(1, averageFloor - 1)
        let upper = max(lower, averageCeiling + 1)
        var results: [[Int]] = []

        func build(remaining: Int, slots: Int, current: [Int]) {
            if slots == 0 {
                guard remaining == 0,
                      let minimum = current.min(),
                      let maximum = current.max(),
                      maximum - minimum <= 2 else { return }
                results.append(current)
                return
            }

            for value in lower...upper {
                let nextRemaining = remaining - value
                guard nextRemaining >= lower * (slots - 1),
                      nextRemaining <= upper * (slots - 1) else { continue }
                build(remaining: nextRemaining, slots: slots - 1, current: current + [value])
            }
        }

        build(remaining: total, slots: parts, current: [])
        return results.sorted { first, second in
            first.lexicographicallyPrecedes(second)
        }
    }

    static func placementsHaveSpacing(_ placements: [Placement], spacing: Double) -> Bool {
        for firstIndex in placements.indices {
            for secondIndex in placements.indices where secondIndex > firstIndex {
                let first = placements[firstIndex].frame.expanded(by: spacing / 2)
                let second = placements[secondIndex].frame.expanded(by: spacing / 2)
                if !first.intersection(second).isEmpty { return false }
            }
        }
        return true
    }

    static func isBetter(_ candidate: Candidate, than current: Candidate?) -> Bool {
        guard let current else { return true }
        if abs(candidate.score - current.score) > 0.000_001 {
            return candidate.score < current.score
        }
        return candidate.rowCounts.lexicographicallyPrecedes(current.rowCounts)
    }
}
