import XCTest
@testable import StepAsideCore

final class WindowMatcherTests: XCTestCase {
    func testMatchesSameProcessWindowsByTitleAndBounds() {
        let cg = [
            CGWindowRecord(
                windowID: 41,
                pid: 7,
                title: "Alpha",
                frame: Rect(x: 0, y: 0, width: 800, height: 600)
            ),
            CGWindowRecord(
                windowID: 42,
                pid: 7,
                title: "Beta",
                frame: Rect(x: 810, y: 0, width: 600, height: 600)
            ),
        ]
        let ax = [
            AXWindowRecord(
                index: 0,
                pid: 7,
                title: "Beta",
                frame: Rect(x: 810, y: 0, width: 600, height: 600)
            ),
            AXWindowRecord(
                index: 1,
                pid: 7,
                title: "Alpha",
                frame: Rect(x: 0, y: 0, width: 800, height: 600)
            ),
        ]

        XCTAssertEqual(
            WindowMatcher().match(cg: cg, ax: ax),
            [
                WindowMatch(windowID: 41, axIndex: 1),
                WindowMatch(windowID: 42, axIndex: 0),
            ]
        )
    }

    func testRejectsAmbiguousUntitledPair() {
        let cg = [
            CGWindowRecord(
                windowID: 1,
                pid: 9,
                title: "",
                frame: Rect(x: 0, y: 0, width: 500, height: 500)
            ),
        ]
        let ax = [
            AXWindowRecord(
                index: 0,
                pid: 9,
                title: "",
                frame: Rect(x: 1, y: 0, width: 500, height: 500)
            ),
            AXWindowRecord(
                index: 1,
                pid: 9,
                title: "",
                frame: Rect(x: 0, y: 1, width: 500, height: 500)
            ),
        ]

        XCTAssertTrue(WindowMatcher().match(cg: cg, ax: ax).isEmpty)
    }

    func testNeverMatchesAcrossProcessesOrLargeGeometryDrift() {
        let cg = [
            CGWindowRecord(
                windowID: 3,
                pid: 10,
                title: "Document",
                frame: Rect(x: 0, y: 0, width: 900, height: 700)
            ),
        ]
        let ax = [
            AXWindowRecord(
                index: 0,
                pid: 11,
                title: "Document",
                frame: Rect(x: 0, y: 0, width: 900, height: 700)
            ),
            AXWindowRecord(
                index: 1,
                pid: 10,
                title: "Document",
                frame: Rect(x: 300, y: 300, width: 900, height: 700)
            ),
        ]

        XCTAssertTrue(WindowMatcher().match(cg: cg, ax: ax).isEmpty)
    }

    func testSmallFrameDriftStillMatchesUniqueWindow() {
        let cg = [
            CGWindowRecord(
                windowID: 8,
                pid: 2,
                title: "Live",
                frame: Rect(x: 100, y: 100, width: 700, height: 500)
            ),
        ]
        let ax = [
            AXWindowRecord(
                index: 4,
                pid: 2,
                title: "Live",
                frame: Rect(x: 101, y: 99, width: 701, height: 499)
            ),
        ]

        XCTAssertEqual(
            WindowMatcher().match(cg: cg, ax: ax),
            [WindowMatch(windowID: 8, axIndex: 4)]
        )
    }
}
