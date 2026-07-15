import XCTest
@testable import StepAsideCore

final class OutcomeCopyTests: XCTestCase {
    func testEveryOutcomeHasConciseCopy() {
        XCTAssertEqual(outcome(.success, arranged: 6).headline, "6 windows · arranged")
        XCTAssertEqual(outcome(.partial, arranged: 5, skipped: 2).headline, "5 arranged · 2 stayed")
        XCTAssertEqual(outcome(.noWindows).headline, "No windows to arrange")
        XCTAssertEqual(outcome(.busy).headline, "Already arranging")
        XCTAssertEqual(outcome(.failed).headline, "Could not arrange windows")
        XCTAssertEqual(outcome(.undone, restored: 4).headline, "4 windows · restored")
        XCTAssertEqual(outcome(.nothingToUndo).headline, "Nothing to restore")
    }

    private func outcome(
        _ status: ArrangementOutcome.Status,
        arranged: Int = 0,
        skipped: Int = 0,
        restored: Int = 0
    ) -> ArrangementOutcome {
        ArrangementOutcome(
            status: status,
            arrangedCount: arranged,
            skippedCount: skipped,
            restoredCount: restored
        )
    }
}
