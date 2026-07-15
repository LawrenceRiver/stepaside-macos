import XCTest
@testable import StepAsideCore

final class ModelTests: XCTestCase {
    func testPreferredAspectRatioIsClampedForLayoutSafety() {
        let wide = WindowSnapshot(
            token: WindowToken(pid: 1, windowID: 10),
            frame: Rect(x: 0, y: 0, width: 10_000, height: 100),
            displayID: 4
        )
        let tall = WindowSnapshot(
            token: WindowToken(pid: 1, windowID: 11),
            frame: Rect(x: 0, y: 0, width: 100, height: 10_000),
            displayID: 4
        )

        XCTAssertEqual(wide.preferredAspectRatio, 4)
        XCTAssertEqual(tall.preferredAspectRatio, 0.25)
    }

    func testLayoutResultStartsWithNoPlacementsOrSkips() {
        let result = LayoutResult()

        XCTAssertTrue(result.placements.isEmpty)
        XCTAssertTrue(result.skipped.isEmpty)
    }
}
