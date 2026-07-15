import XCTest
@testable import StepAsideCore

final class GeometryTests: XCTestCase {
    func testIntersectionReturnsSharedPositiveArea() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 50, y: 30, width: 90, height: 40)

        XCTAssertEqual(a.intersection(b), Rect(x: 50, y: 30, width: 50, height: 40))
        XCTAssertEqual(a.intersection(Rect(x: 200, y: 0, width: 10, height: 10)), .zero)
    }

    func testInsetReducesEveryEdge() {
        let rect = Rect(x: 0, y: 0, width: 100, height: 100)

        XCTAssertEqual(rect.insetBy(dx: 10, dy: 12), Rect(x: 10, y: 12, width: 80, height: 76))
    }
}
