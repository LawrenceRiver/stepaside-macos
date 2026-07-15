import XCTest
@testable import StepAsideCore

final class SystemValueTests: XCTestCase {
    func testSpacingPreferencesHaveStablePointValues() {
        XCTAssertEqual(SpacingPreference.compact.points, 8)
        XCTAssertEqual(SpacingPreference.balanced.points, 12)
        XCTAssertEqual(SpacingPreference.airy.points, 18)
        XCTAssertEqual(SpacingPreference(rawValue: "unknown") ?? .balanced, .balanced)
    }

    func testVisibleFrameConversionPreservesMenuBarAndDockInsets() {
        let appKitFrame = Rect(x: 0, y: 0, width: 1_440, height: 900)
        let appKitVisible = Rect(x: 0, y: 70, width: 1_440, height: 805)
        let cgBounds = Rect(x: 0, y: 0, width: 1_440, height: 900)

        let converted = DisplayGeometry.coreGraphicsVisibleFrame(
            appKitFrame: appKitFrame,
            appKitVisibleFrame: appKitVisible,
            coreGraphicsBounds: cgBounds
        )

        XCTAssertEqual(converted, Rect(x: 0, y: 25, width: 1_440, height: 805))
    }

    func testVisibleFrameConversionSupportsDisplayLeftOfPrimary() {
        let converted = DisplayGeometry.coreGraphicsVisibleFrame(
            appKitFrame: Rect(x: -1_280, y: 0, width: 1_280, height: 800),
            appKitVisibleFrame: Rect(x: -1_280, y: 0, width: 1_280, height: 775),
            coreGraphicsBounds: Rect(x: -1_280, y: 100, width: 1_280, height: 800)
        )

        XCTAssertEqual(converted, Rect(x: -1_280, y: 125, width: 1_280, height: 775))
    }
}
