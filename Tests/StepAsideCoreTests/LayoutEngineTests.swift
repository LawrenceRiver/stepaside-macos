import XCTest
@testable import StepAsideCore

final class LayoutEngineTests: XCTestCase {
    private let display = DisplaySnapshot(
        id: 1,
        visibleFrame: Rect(x: 0, y: 0, width: 1_440, height: 900)
    )

    private func window(
        _ id: UInt32,
        x: Double = 0,
        y: Double = 0,
        width: Double = 900,
        height: Double = 650,
        displayID: UInt32 = 1,
        minimumWidth: Double = 160,
        minimumHeight: Double = 120,
        isResizable: Bool = true
    ) -> WindowSnapshot {
        WindowSnapshot(
            token: WindowToken(pid: Int32(id), windowID: id),
            frame: Rect(x: x, y: y, width: width, height: height),
            displayID: displayID,
            minimumWidth: minimumWidth,
            minimumHeight: minimumHeight,
            isResizable: isResizable
        )
    }

    func testFiveWindowsStayInBoundsWithTwelvePointSpacing() {
        let result = LayoutEngine().layout(
            windows: (1...5).map { window(UInt32($0)) },
            displays: [display],
            spacing: 12
        )

        XCTAssertEqual(result.placements.count, 5)
        XCTAssertTrue(result.skipped.isEmpty)
        assertValid(result.placements, in: display.visibleFrame.insetBy(dx: 12, dy: 12), spacing: 12)
    }

    func testResultIsDeterministicAndPreservesSourceDisplays() {
        let second = DisplaySnapshot(
            id: 2,
            visibleFrame: Rect(x: 1_440, y: 0, width: 1_280, height: 800)
        )
        let input = [
            window(1, x: 0, y: 0),
            window(2, x: 400, y: 100),
            window(3, x: 1_440, y: 0, displayID: 2),
            window(4, x: 1_700, y: 80, displayID: 2),
        ]

        let first = LayoutEngine().layout(windows: input, displays: [display, second], spacing: 12)
        let again = LayoutEngine().layout(windows: input, displays: [display, second], spacing: 12)

        XCTAssertEqual(first, again)
        for placement in first.placements {
            let original = input.first { $0.token == placement.token }
            let target = [display, second].first { $0.id == original?.displayID }
            XCTAssertNotNil(target)
            XCTAssertTrue(target!.visibleFrame.insetBy(dx: 12, dy: 12).contains(placement.frame))
        }
    }

    func testNonResizableWindowStaysFixedAndOtherFramesAvoidIt() {
        let fixed = window(
            1,
            x: 12,
            y: 12,
            width: 500,
            height: 300,
            isResizable: false
        )

        let result = LayoutEngine().layout(
            windows: [fixed, window(2), window(3)],
            displays: [display],
            spacing: 12
        )

        XCTAssertEqual(result.placements.first { $0.token == fixed.token }?.frame, fixed.frame)
        XCTAssertEqual(result.placements.count, 3)
        assertValid(result.placements, in: display.visibleFrame.insetBy(dx: 12, dy: 12), spacing: 12)
    }

    func testImpossibleMinimumSizesAreSkippedInsteadOfOverlapped() {
        let tiny = DisplaySnapshot(
            id: 3,
            visibleFrame: Rect(x: 0, y: 0, width: 600, height: 400)
        )
        let windows = (1...6).map {
            window(
                UInt32($0),
                displayID: 3,
                minimumWidth: 400,
                minimumHeight: 300
            )
        }

        let result = LayoutEngine().layout(windows: windows, displays: [tiny], spacing: 12)

        XCTAssertLessThan(result.placements.count, windows.count)
        XCTAssertEqual(result.placements.count + result.skipped.count, windows.count)
        XCTAssertTrue(result.skipped.values.allSatisfy { $0 == .insufficientSpace })
        assertValid(result.placements, in: tiny.visibleFrame.insetBy(dx: 12, dy: 12), spacing: 12)
    }

    func testPlacementsAcrossSiblingFreeRectanglesKeepGlobalSpacing() {
        let fixed = window(
            1,
            x: 12,
            y: 12,
            width: 500,
            height: 300,
            isResizable: false
        )
        let constrained = (2...9).map {
            window(
                UInt32($0),
                minimumWidth: 400,
                minimumHeight: 220
            )
        }

        let result = LayoutEngine().layout(
            windows: [fixed] + constrained,
            displays: [display],
            spacing: 12
        )

        assertValid(result.placements, in: display.visibleFrame.insetBy(dx: 12, dy: 12), spacing: 12)
    }

    func testWindowOnUnknownDisplayIsReportedAsInsufficientSpace() {
        let orphan = window(88, displayID: 99)

        let result = LayoutEngine().layout(windows: [orphan], displays: [display], spacing: 12)

        XCTAssertTrue(result.placements.isEmpty)
        XCTAssertEqual(result.skipped[orphan.token], .insufficientSpace)
    }

    func testOneThroughTwentyOrdinaryWindowsAlwaysRespectLayoutInvariants() {
        for count in 1...20 {
            var windows: [WindowSnapshot] = []
            for index in 1...count {
                let snapshot = window(
                    UInt32(index),
                    x: Double((index * 73) % 900),
                    y: Double((index * 41) % 500),
                    width: Double(540 + (index % 4) * 120),
                    height: Double(360 + (index % 3) * 90)
                )
                windows.append(snapshot)
            }
            let result = LayoutEngine().layout(windows: windows, displays: [display], spacing: 12)

            XCTAssertEqual(result.placements.count, count, "Unexpected skip at count \(count)")
            XCTAssertTrue(result.skipped.isEmpty, "Unexpected skip at count \(count)")
            assertValid(result.placements, in: display.visibleFrame.insetBy(dx: 12, dy: 12), spacing: 12)
        }
    }

    private func assertValid(
        _ placements: [Placement],
        in bounds: Rect,
        spacing: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for placement in placements {
            XCTAssertTrue(bounds.contains(placement.frame), "Out of bounds: \(placement)", file: file, line: line)
        }
        for firstIndex in placements.indices {
            for secondIndex in placements.indices where secondIndex > firstIndex {
                let first = placements[firstIndex].frame.expanded(by: spacing / 2)
                let second = placements[secondIndex].frame.expanded(by: spacing / 2)
                XCTAssertTrue(
                    first.intersection(second).isEmpty,
                    "Overlap: \(placements[firstIndex]) and \(placements[secondIndex])",
                    file: file,
                    line: line
                )
            }
        }
    }
}
