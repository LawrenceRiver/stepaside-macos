import Foundation

public protocol WindowSystem: Sendable {
    func discover() async throws -> DiscoverySnapshot
    func setFrame(_ frame: Rect, for token: WindowToken) async throws
    func frame(for token: WindowToken) async -> Rect?
}

public struct ArrangementOutcome: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case success
        case partial
        case noWindows
        case busy
        case failed
        case undone
        case nothingToUndo
    }

    public let status: Status
    public let arrangedCount: Int
    public let skippedCount: Int
    public let restoredCount: Int

    public init(
        status: Status,
        arrangedCount: Int,
        skippedCount: Int,
        restoredCount: Int
    ) {
        self.status = status
        self.arrangedCount = arrangedCount
        self.skippedCount = skippedCount
        self.restoredCount = restoredCount
    }

    public var headline: String {
        switch status {
        case .success:
            "\(arrangedCount) windows · arranged"
        case .partial:
            "\(arrangedCount) arranged · \(skippedCount) stayed"
        case .noWindows:
            "No windows to arrange"
        case .busy:
            "Already arranging"
        case .failed:
            "Could not arrange windows"
        case .undone:
            "\(restoredCount) windows · restored"
        case .nothingToUndo:
            "Nothing to restore"
        }
    }
}

public actor ArrangementCoordinator {
    private let windowSystem: any WindowSystem
    private let layoutEngine: any LayoutCalculating
    private let settleNanoseconds: UInt64
    private var isRunning = false
    private var undoFrames: [WindowToken: Rect] = [:]

    public init(
        windowSystem: any WindowSystem,
        layoutEngine: any LayoutCalculating,
        settleNanoseconds: UInt64 = 80_000_000
    ) {
        self.windowSystem = windowSystem
        self.layoutEngine = layoutEngine
        self.settleNanoseconds = settleNanoseconds
    }

    public func arrange(spacing: Double) async -> ArrangementOutcome {
        guard !isRunning else { return outcome(.busy) }
        isRunning = true
        defer { isRunning = false }

        do {
            let discovery = try await windowSystem.discover()
            guard !discovery.windows.isEmpty else { return outcome(.noWindows) }

            let layout = layoutEngine.layout(
                windows: discovery.windows,
                displays: discovery.displays,
                spacing: spacing
            )
            let originals = Dictionary(
                uniqueKeysWithValues: discovery.windows.map { ($0.token, $0.frame) }
            )
            var pending: [Placement] = []

            for placement in layout.placements {
                do {
                    try await windowSystem.setFrame(placement.frame, for: placement.token)
                    pending.append(placement)
                } catch {
                    continue
                }
            }

            await settle()
            var successful: Set<WindowToken> = []

            for placement in pending {
                guard let observed = await windowSystem.frame(for: placement.token) else { continue }
                if Self.framesMatch(observed, placement.frame) {
                    successful.insert(placement.token)
                    continue
                }

                do {
                    try await windowSystem.setFrame(placement.frame, for: placement.token)
                    await settle()
                    if let retried = await windowSystem.frame(for: placement.token),
                       Self.framesMatch(retried, placement.frame) {
                        successful.insert(placement.token)
                    }
                } catch {
                    continue
                }
            }

            if !successful.isEmpty {
                undoFrames = originals.filter { successful.contains($0.key) }
            }

            let skippedCount = discovery.windows.count - successful.count
            return ArrangementOutcome(
                status: skippedCount == 0 ? .success : .partial,
                arrangedCount: successful.count,
                skippedCount: skippedCount,
                restoredCount: 0
            )
        } catch {
            return outcome(.failed)
        }
    }

    public func undo() async -> ArrangementOutcome {
        guard !isRunning else { return outcome(.busy) }
        guard !undoFrames.isEmpty else { return outcome(.nothingToUndo) }
        isRunning = true
        defer { isRunning = false }

        let snapshot = undoFrames
        var restored = 0
        var skipped = 0

        for (token, frame) in snapshot.sorted(by: { $0.key.windowID < $1.key.windowID }) {
            guard await windowSystem.frame(for: token) != nil else {
                skipped += 1
                continue
            }
            do {
                try await windowSystem.setFrame(frame, for: token)
                restored += 1
            } catch {
                skipped += 1
            }
        }

        undoFrames.removeAll()
        return ArrangementOutcome(
            status: restored > 0 ? .undone : .partial,
            arrangedCount: 0,
            skippedCount: skipped,
            restoredCount: restored
        )
    }

    public func hasUndoSnapshot() -> Bool {
        !undoFrames.isEmpty
    }
}

private extension ArrangementCoordinator {
    func settle() async {
        guard settleNanoseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: settleNanoseconds)
    }

    func outcome(_ status: ArrangementOutcome.Status) -> ArrangementOutcome {
        ArrangementOutcome(
            status: status,
            arrangedCount: 0,
            skippedCount: 0,
            restoredCount: 0
        )
    }

    static func framesMatch(_ first: Rect, _ second: Rect, tolerance: Double = 2) -> Bool {
        abs(first.x - second.x) <= tolerance
            && abs(first.y - second.y) <= tolerance
            && abs(first.width - second.width) <= tolerance
            && abs(first.height - second.height) <= tolerance
    }
}
