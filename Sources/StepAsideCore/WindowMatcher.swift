import Foundation

public struct CGWindowRecord: Equatable, Sendable {
    public let windowID: UInt32
    public let pid: Int32
    public let title: String
    public let frame: Rect

    public init(windowID: UInt32, pid: Int32, title: String, frame: Rect) {
        self.windowID = windowID
        self.pid = pid
        self.title = title
        self.frame = frame
    }
}

public struct AXWindowRecord: Equatable, Sendable {
    public let index: Int
    public let pid: Int32
    public let title: String
    public let frame: Rect

    public init(index: Int, pid: Int32, title: String, frame: Rect) {
        self.index = index
        self.pid = pid
        self.title = title
        self.frame = frame
    }
}

public struct WindowMatch: Equatable, Sendable {
    public let windowID: UInt32
    public let axIndex: Int

    public init(windowID: UInt32, axIndex: Int) {
        self.windowID = windowID
        self.axIndex = axIndex
    }
}

public struct WindowMatcher: Sendable {
    public init() {}

    public func match(
        cg: [CGWindowRecord],
        ax: [AXWindowRecord]
    ) -> [WindowMatch] {
        var unusedIndices = Set(ax.indices)
        var matches: [WindowMatch] = []

        for cgRecord in cg.sorted(by: { $0.windowID < $1.windowID }) {
            let candidates = unusedIndices.compactMap { sourceIndex -> ScoredCandidate? in
                guard let score = score(cgRecord, ax[sourceIndex]) else { return nil }
                return ScoredCandidate(sourceIndex: sourceIndex, score: score)
            }.sorted {
                if $0.score != $1.score { return $0.score < $1.score }
                return ax[$0.sourceIndex].index < ax[$1.sourceIndex].index
            }

            guard let best = candidates.first else { continue }
            if candidates.count > 1, candidates[1].score - best.score <= 1 { continue }

            let axRecord = ax[best.sourceIndex]
            matches.append(WindowMatch(windowID: cgRecord.windowID, axIndex: axRecord.index))
            unusedIndices.remove(best.sourceIndex)
        }

        return matches.sorted { $0.windowID < $1.windowID }
    }
}

private extension WindowMatcher {
    struct ScoredCandidate {
        let sourceIndex: Int
        let score: Double
    }

    func score(_ cg: CGWindowRecord, _ ax: AXWindowRecord) -> Double? {
        guard cg.pid == ax.pid else { return nil }
        let cgTitle = normalized(cg.title)
        let axTitle = normalized(ax.title)
        let titlePenalty: Double
        if cgTitle == axTitle {
            titlePenalty = cgTitle.isEmpty ? 8 : 0
        } else if cgTitle.isEmpty || axTitle.isEmpty {
            titlePenalty = 25
        } else {
            return nil
        }

        let edgeDelta = abs(cg.frame.minX - ax.frame.minX)
            + abs(cg.frame.minY - ax.frame.minY)
            + abs(cg.frame.width - ax.frame.width)
            + abs(cg.frame.height - ax.frame.height)
        guard edgeDelta <= 40 else { return nil }
        return titlePenalty + edgeDelta
    }

    func normalized(_ title: String) -> String {
        title.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
