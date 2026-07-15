import XCTest
@testable import StepAsideCore

final class ArrangementCoordinatorTests: XCTestCase {
    func testArrangeAppliesFramesAndUndoRestoresOriginals() async {
        let token = WindowToken(pid: 1, windowID: 1)
        let original = Rect(x: 50, y: 50, width: 800, height: 600)
        let system = FakeWindowSystem(windows: [
            WindowSnapshot(token: token, frame: original, displayID: 1),
        ])
        let coordinator = ArrangementCoordinator(
            windowSystem: system,
            layoutEngine: LayoutEngine(),
            settleNanoseconds: 0
        )

        let arranged = await coordinator.arrange(spacing: 12)
        XCTAssertEqual(arranged.status, .success)
        XCTAssertEqual(arranged.arrangedCount, 1)
        let arrangedFrame = await system.currentFrame(token)
        XCTAssertNotEqual(arrangedFrame, original)

        let undone = await coordinator.undo()
        XCTAssertEqual(undone.status, .undone)
        XCTAssertEqual(undone.restoredCount, 1)
        let restoredFrame = await system.currentFrame(token)
        XCTAssertEqual(restoredFrame, original)
    }

    func testConcurrentArrangeReturnsBusy() async {
        let window = WindowSnapshot(
            token: WindowToken(pid: 1, windowID: 1),
            frame: Rect(x: 0, y: 0, width: 800, height: 600),
            displayID: 1
        )
        let system = FakeWindowSystem(
            windows: [window],
            applyDelayNanoseconds: 200_000_000
        )
        let coordinator = ArrangementCoordinator(
            windowSystem: system,
            layoutEngine: LayoutEngine(),
            settleNanoseconds: 0
        )

        async let first = coordinator.arrange(spacing: 12)
        try? await Task.sleep(nanoseconds: 20_000_000)
        let second = await coordinator.arrange(spacing: 12)

        XCTAssertEqual(second.status, .busy)
        _ = await first
    }

    func testVerificationRetriesARejectedFrameOnce() async {
        let token = WindowToken(pid: 1, windowID: 1)
        let system = FakeWindowSystem(
            windows: [
                WindowSnapshot(
                    token: token,
                    frame: Rect(x: 0, y: 0, width: 800, height: 600),
                    displayID: 1
                ),
            ],
            ignoredWritesByToken: [token: 1]
        )
        let coordinator = ArrangementCoordinator(
            windowSystem: system,
            layoutEngine: LayoutEngine(),
            settleNanoseconds: 0
        )

        let outcome = await coordinator.arrange(spacing: 12)

        XCTAssertEqual(outcome.status, .success)
        let writes = await system.writeCount(token)
        XCTAssertEqual(writes, 2)
    }

    func testPersistentFrameRejectionProducesPartialOutcome() async {
        let token = WindowToken(pid: 1, windowID: 1)
        let system = FakeWindowSystem(
            windows: [
                WindowSnapshot(
                    token: token,
                    frame: Rect(x: 0, y: 0, width: 800, height: 600),
                    displayID: 1
                ),
            ],
            ignoredWritesByToken: [token: 10]
        )
        let coordinator = ArrangementCoordinator(
            windowSystem: system,
            layoutEngine: LayoutEngine(),
            settleNanoseconds: 0
        )

        let outcome = await coordinator.arrange(spacing: 12)

        XCTAssertEqual(outcome.status, .partial)
        XCTAssertEqual(outcome.arrangedCount, 0)
        XCTAssertEqual(outcome.skippedCount, 1)
    }

    func testEmptyDiscoveryAndEmptyUndoReturnNeutralOutcomes() async {
        let system = FakeWindowSystem(windows: [])
        let coordinator = ArrangementCoordinator(
            windowSystem: system,
            layoutEngine: LayoutEngine(),
            settleNanoseconds: 0
        )

        let arrangement = await coordinator.arrange(spacing: 12)
        let undo = await coordinator.undo()
        XCTAssertEqual(arrangement.status, .noWindows)
        XCTAssertEqual(undo.status, .nothingToUndo)
    }
}

private actor FakeWindowSystem: WindowSystem {
    enum Failure: Error { case rejected }

    private let display = DisplaySnapshot(
        id: 1,
        visibleFrame: Rect(x: 0, y: 0, width: 1_440, height: 900)
    )
    private var snapshots: [WindowToken: WindowSnapshot]
    private var frames: [WindowToken: Rect]
    private var writes: [WindowToken: Int] = [:]
    private var ignoredWritesByToken: [WindowToken: Int]
    private let applyDelayNanoseconds: UInt64

    init(
        windows: [WindowSnapshot],
        applyDelayNanoseconds: UInt64 = 0,
        ignoredWritesByToken: [WindowToken: Int] = [:]
    ) {
        snapshots = Dictionary(uniqueKeysWithValues: windows.map { ($0.token, $0) })
        frames = Dictionary(uniqueKeysWithValues: windows.map { ($0.token, $0.frame) })
        self.applyDelayNanoseconds = applyDelayNanoseconds
        self.ignoredWritesByToken = ignoredWritesByToken
    }

    func discover() async throws -> DiscoverySnapshot {
        DiscoverySnapshot(
            windows: snapshots.values.sorted { $0.token.windowID < $1.token.windowID },
            displays: [display]
        )
    }

    func setFrame(_ frame: Rect, for token: WindowToken) async throws {
        if applyDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: applyDelayNanoseconds)
        }
        writes[token, default: 0] += 1
        guard frames[token] != nil else { throw Failure.rejected }
        if ignoredWritesByToken[token, default: 0] > 0 {
            ignoredWritesByToken[token, default: 0] -= 1
            return
        }
        frames[token] = frame
    }

    func frame(for token: WindowToken) async -> Rect? {
        frames[token]
    }

    func currentFrame(_ token: WindowToken) -> Rect? {
        frames[token]
    }

    func writeCount(_ token: WindowToken) -> Int {
        writes[token, default: 0]
    }
}
