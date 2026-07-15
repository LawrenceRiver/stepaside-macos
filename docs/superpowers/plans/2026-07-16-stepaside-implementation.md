# StepAside Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a release-ready macOS menu-bar app that arranges every eligible window on the current Space into a non-overlapping adaptive layout and can undo the last arrangement.

**Architecture:** A dependency-free Swift Package separates a pure `StepAsideCore` library from the AppKit/SwiftUI `StepAside` executable. Core Graphics identifies on-screen windows, Accessibility reads and changes their geometry, and a pure adaptive-row solver produces deterministic placements that are verified after application.

**Tech Stack:** Swift 6.3, Swift Package Manager, AppKit, SwiftUI, ApplicationServices Accessibility, CoreGraphics, ServiceManagement, Carbon hotkeys, XCTest, shell packaging tools, macOS 14+

## Global Constraints

- Target macOS 14 or later and build on the installed macOS 26.5 SDK.
- Use no third-party runtime dependency and no private SkyLight or WindowServer API.
- Use Accessibility permission only; do not add Screen Recording, Input Monitoring, Full Disk Access, clipboard, analytics, or network behavior.
- Arrange only ordinary windows visible in the current Space and keep each window on its source display.
- Never overlap successful placements; return explicit skip reasons when minimum sizes make the layout infeasible.
- Keep the default outer and inter-window spacing at 12 pt.
- Preserve one in-memory undo snapshot and ignore concurrent Arrange actions.
- Keep the app out of the Dock and make left-click arrange immediately.
- Use an original warm-ivory, black, yellow, pale-blue, and coral editorial visual system without copying the supplied reference.
- Produce `StepAside.app`, `StepAside.dmg`, a complete `.icns`, automated tests, documentation, and a GitHub release checklist.

---

## File map

- `Package.swift`: library, executable, and test target definitions.
- `Sources/StepAsideCore/Geometry.swift`: platform-neutral rectangle math.
- `Sources/StepAsideCore/Models.swift`: immutable window, display, placement, and result types.
- `Sources/StepAsideCore/LayoutEngine.swift`: adaptive row solver, fixed-window obstacle handling, and invariants.
- `Sources/StepAsideCore/WindowMatcher.swift`: deterministic Core Graphics to Accessibility record matching.
- `Sources/StepAsideCore/ArrangementCoordinator.swift`: serialized arrange/undo transactions and verification.
- `Sources/StepAside/StepAsideApplication.swift`: application entry point and delegate ownership.
- `Sources/StepAside/MacWindowSystem.swift`: public macOS window discovery and Accessibility mutation.
- `Sources/StepAside/AccessibilityGate.swift`: permission status and prompt.
- `Sources/StepAside/StatusItemController.swift`: left/right-click status item behavior.
- `Sources/StepAside/HUDController.swift`: nonactivating completion HUD.
- `Sources/StepAside/SettingsController.swift`: onboarding and settings window ownership.
- `Sources/StepAside/SettingsView.swift`: editorial SwiftUI onboarding and settings UI.
- `Sources/StepAside/GlobalHotKeyService.swift`: `Control-Option-S` registration.
- `Sources/StepAside/LaunchAtLoginService.swift`: `SMAppService` wrapper.
- `Sources/StepAside/Preferences.swift`: typed local defaults.
- `Sources/StepAside/Resources/Info.plist`: app bundle metadata.
- `Sources/StepAside/Resources/AppIcon.icns`: packaged icon.
- `Brand/AppIcon-1024.png`: inspected master icon.
- `Brand/AppIcon.iconset/*`: macOS icon renditions.
- `Tests/StepAsideCoreTests/*`: geometry, layout, matching, and coordination tests.
- `scripts/build-app.sh`: reproducible `.app` assembly and signing.
- `scripts/build-dmg.sh`: DMG creation.
- `scripts/generate-icons.sh`: deterministic master-to-iconset conversion.
- `Makefile`: common test, app, and DMG commands.
- `.github/workflows/ci.yml`: clean Swift build and test.
- `README.md`, `PRIVACY.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `RELEASE.md`, `LICENSE`: public repository material.

### Task 1: Bootstrap the package and geometry model

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/StepAsideCore/Geometry.swift`
- Create: `Sources/StepAsideCore/Models.swift`
- Create: `Tests/StepAsideCoreTests/GeometryTests.swift`

**Interfaces:**
- Consumes: None.
- Produces: `Rect`, `WindowToken`, `DisplaySnapshot`, `WindowSnapshot`, `Placement`, `SkipReason`, `LayoutResult`, and `DiscoverySnapshot`.

- [ ] **Step 1: Add the package manifest and a failing geometry test**

```swift
// Package.swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StepAside",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StepAsideCore", targets: ["StepAsideCore"]),
        .executable(name: "StepAside", targets: ["StepAside"]),
    ],
    targets: [
        .target(name: "StepAsideCore"),
        .executableTarget(name: "StepAside", dependencies: ["StepAsideCore"]),
        .testTarget(name: "StepAsideCoreTests", dependencies: ["StepAsideCore"]),
    ]
)
```

```swift
// Tests/StepAsideCoreTests/GeometryTests.swift
import XCTest
@testable import StepAsideCore

final class GeometryTests: XCTestCase {
    func testIntersectionAndInsetUsePositiveAreas() {
        let a = Rect(x: 0, y: 0, width: 100, height: 100)
        let b = Rect(x: 50, y: 30, width: 90, height: 40)
        XCTAssertEqual(a.intersection(b), Rect(x: 50, y: 30, width: 50, height: 40))
        XCTAssertEqual(a.insetBy(dx: 10, dy: 12), Rect(x: 10, y: 12, width: 80, height: 76))
        XCTAssertEqual(a.intersection(Rect(x: 200, y: 0, width: 10, height: 10)), .zero)
    }
}
```

- [ ] **Step 2: Run the focused test and confirm the missing-module failure**

Run: `swift test --filter GeometryTests`

Expected: FAIL because `StepAsideCore` has no `Rect` implementation.

- [ ] **Step 3: Implement geometry and immutable models**

```swift
// Sources/StepAsideCore/Geometry.swift
import Foundation

public struct Rect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)
    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var area: Double { max(0, width) * max(0, height) }
    public var isEmpty: Bool { width <= 0 || height <= 0 }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public func insetBy(dx: Double, dy: Double) -> Rect {
        Rect(x: x + dx, y: y + dy, width: max(0, width - dx * 2), height: max(0, height - dy * 2))
    }

    public func expanded(by amount: Double) -> Rect {
        Rect(x: x - amount, y: y - amount, width: width + amount * 2, height: height + amount * 2)
    }

    public func intersection(_ other: Rect) -> Rect {
        let left = max(minX, other.minX), top = max(minY, other.minY)
        let right = min(maxX, other.maxX), bottom = min(maxY, other.maxY)
        guard right > left, bottom > top else { return .zero }
        return Rect(x: left, y: top, width: right - left, height: bottom - top)
    }

    public func contains(_ other: Rect, tolerance: Double = 0.5) -> Bool {
        other.minX >= minX - tolerance && other.minY >= minY - tolerance &&
        other.maxX <= maxX + tolerance && other.maxY <= maxY + tolerance
    }

    public func distanceSquared(to other: Rect) -> Double {
        let dx = midX - other.midX, dy = midY - other.midY
        return dx * dx + dy * dy
    }
}
```

```swift
// Sources/StepAsideCore/Models.swift
import Foundation

public struct WindowToken: Hashable, Codable, Sendable {
    public let pid: Int32
    public let windowID: UInt32
    public init(pid: Int32, windowID: UInt32) { self.pid = pid; self.windowID = windowID }
}

public struct DisplaySnapshot: Equatable, Sendable {
    public let id: UInt32
    public let visibleFrame: Rect
    public init(id: UInt32, visibleFrame: Rect) { self.id = id; self.visibleFrame = visibleFrame }
}

public struct WindowSnapshot: Equatable, Sendable {
    public let token: WindowToken
    public let frame: Rect
    public let displayID: UInt32
    public let minimumWidth: Double
    public let minimumHeight: Double
    public let isResizable: Bool
    public init(token: WindowToken, frame: Rect, displayID: UInt32, minimumWidth: Double = 160,
                minimumHeight: Double = 120, isResizable: Bool = true) {
        self.token = token; self.frame = frame; self.displayID = displayID
        self.minimumWidth = minimumWidth; self.minimumHeight = minimumHeight
        self.isResizable = isResizable
    }
    public var preferredAspectRatio: Double { min(4, max(0.25, frame.width / max(1, frame.height))) }
}

public struct Placement: Equatable, Sendable {
    public let token: WindowToken
    public let frame: Rect
    public init(token: WindowToken, frame: Rect) { self.token = token; self.frame = frame }
}

public enum SkipReason: String, Equatable, Sendable {
    case ambiguousMatch, cannotMove, insufficientSpace, disappeared, rejectedFrame
}

public struct LayoutResult: Equatable, Sendable {
    public var placements: [Placement]
    public var skipped: [WindowToken: SkipReason]
    public init(placements: [Placement] = [], skipped: [WindowToken: SkipReason] = [:]) {
        self.placements = placements; self.skipped = skipped
    }
}

public struct DiscoverySnapshot: Equatable, Sendable {
    public let windows: [WindowSnapshot]
    public let displays: [DisplaySnapshot]
    public init(windows: [WindowSnapshot], displays: [DisplaySnapshot]) {
        self.windows = windows; self.displays = displays
    }
}
```

- [ ] **Step 4: Add generated-file exclusions and make the package compile**

```gitignore
.build/
.swiftpm/
.DS_Store
dist/
*.dmg
DerivedData/
```

Create `Sources/StepAside/StepAsideApplication.swift` with a temporary compilable entry point:

```swift
import Foundation

@main
enum StepAsideApplication {
    static func main() {
        print("StepAside")
    }
}
```

Run: `swift test --filter GeometryTests`

Expected: PASS, 1 test with 3 assertions.

- [ ] **Step 5: Commit the foundational types**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "feat: bootstrap StepAside core models"
```

### Task 2: Implement the adaptive, non-overlapping layout engine

**Files:**
- Create: `Sources/StepAsideCore/LayoutEngine.swift`
- Create: `Tests/StepAsideCoreTests/LayoutEngineTests.swift`

**Interfaces:**
- Consumes: `Rect`, `WindowSnapshot`, `DisplaySnapshot`, `Placement`, `LayoutResult`.
- Produces: `LayoutCalculating.layout(windows:displays:spacing:) -> LayoutResult` and `LayoutEngine`.

- [ ] **Step 1: Write tests for odd counts, multiple displays, fixed constraints, and impossible density**

```swift
import XCTest
@testable import StepAsideCore

final class LayoutEngineTests: XCTestCase {
    private let display = DisplaySnapshot(id: 1, visibleFrame: Rect(x: 0, y: 0, width: 1440, height: 900))

    private func window(_ id: UInt32, x: Double = 0, y: Double = 0, width: Double = 900,
                        height: Double = 650, displayID: UInt32 = 1, minWidth: Double = 160,
                        minHeight: Double = 120, resizable: Bool = true) -> WindowSnapshot {
        WindowSnapshot(token: WindowToken(pid: Int32(id), windowID: id),
                       frame: Rect(x: x, y: y, width: width, height: height), displayID: displayID,
                       minimumWidth: minWidth, minimumHeight: minHeight, isResizable: resizable)
    }

    func testFiveWindowsFillBoundsWithoutOverlap() {
        let result = LayoutEngine().layout(windows: (1...5).map { window(UInt32($0)) }, displays: [display], spacing: 12)
        XCTAssertEqual(result.placements.count, 5)
        XCTAssertTrue(result.skipped.isEmpty)
        let usable = display.visibleFrame.insetBy(dx: 12, dy: 12)
        for placement in result.placements { XCTAssertTrue(usable.contains(placement.frame)) }
        for i in result.placements.indices {
            for j in result.placements.indices where j > i {
                XCTAssertTrue(result.placements[i].frame.expanded(by: 5.9).intersection(result.placements[j].frame.expanded(by: 5.9)).isEmpty)
            }
        }
    }

    func testResultIsDeterministicAndPreservesDisplays() {
        let second = DisplaySnapshot(id: 2, visibleFrame: Rect(x: 1440, y: 0, width: 1280, height: 800))
        let input = [window(1), window(2), window(3, displayID: 2), window(4, displayID: 2)]
        let first = LayoutEngine().layout(windows: input, displays: [display, second], spacing: 12)
        let again = LayoutEngine().layout(windows: input, displays: [display, second], spacing: 12)
        XCTAssertEqual(first, again)
        for placement in first.placements {
            let original = input.first { $0.token == placement.token }!
            let target = [display, second].first { $0.id == original.displayID }!
            XCTAssertTrue(target.visibleFrame.contains(placement.frame))
        }
    }

    func testNonResizableWindowStaysFixedAndOtherFramesAvoidIt() {
        let fixed = window(1, x: 12, y: 12, width: 500, height: 300, resizable: false)
        let result = LayoutEngine().layout(windows: [fixed, window(2), window(3)], displays: [display], spacing: 12)
        XCTAssertEqual(result.placements.first { $0.token == fixed.token }?.frame, fixed.frame)
        for placement in result.placements where placement.token != fixed.token {
            XCTAssertTrue(placement.frame.expanded(by: 6).intersection(fixed.frame.expanded(by: 6)).isEmpty)
        }
    }

    func testImpossibleMinimumSizesAreSkippedInsteadOfOverlapped() {
        let tiny = DisplaySnapshot(id: 3, visibleFrame: Rect(x: 0, y: 0, width: 600, height: 400))
        let windows = (1...6).map { window(UInt32($0), displayID: 3, minWidth: 400, minHeight: 300) }
        let result = LayoutEngine().layout(windows: windows, displays: [tiny], spacing: 12)
        XCTAssertLessThan(result.placements.count, windows.count)
        XCTAssertEqual(result.placements.count + result.skipped.count, windows.count)
        XCTAssertTrue(result.skipped.values.allSatisfy { $0 == .insufficientSpace })
    }
}
```

- [ ] **Step 2: Run the tests and confirm the missing-engine failure**

Run: `swift test --filter LayoutEngineTests`

Expected: FAIL because `LayoutEngine` is undefined.

- [ ] **Step 3: Implement `LayoutEngine` with deterministic candidate search**

Implement these exact public interfaces:

```swift
public protocol LayoutCalculating: Sendable {
    func layout(windows: [WindowSnapshot], displays: [DisplaySnapshot], spacing: Double) -> LayoutResult
}

public struct LayoutEngine: LayoutCalculating, Sendable {
    public init() {}
    public func layout(windows: [WindowSnapshot], displays: [DisplaySnapshot], spacing: Double) -> LayoutResult
}
```

The implementation must perform the following concrete sequence:

1. Sort each display group by `frame.minY`, then `frame.minX`, then `token.windowID`.
2. Insert non-resizable windows at their current frame when the frame is contained in the inset visible frame and does not collide with an earlier fixed window; otherwise mark them `.insufficientSpace`.
3. Subtract each fixed frame expanded by `spacing / 2` from the display's inset frame. `subtract(_:obstacle:)` returns the nonempty top, bottom, left, and right strips and removes strips contained by another strip.
4. Sort free rectangles by descending area, then ascending `minY`, then ascending `minX`.
5. For every prefix of remaining windows, call `bestRows(windows:in:spacing:)`. Try window counts from the full count downward until a feasible set is found; skipped suffix windows receive `.insufficientSpace`.
6. In `bestRows`, enumerate row counts from 1 through the window count and balanced positive row compositions whose largest and smallest counts differ by at most 2.
7. Compute each row's natural height as `(container.width - spacing * Double(count - 1)) / sum(aspectRatios)`, normalize row heights to fill `container.height - spacing * Double(rowCount - 1)`, and allocate row widths proportionally to aspect ratio.
8. Reject frames that violate minimum width, minimum height, bounds, or pairwise spacing.
9. Score feasible candidates by `abs(log(normalizationScale)) * 1000 + rowHeightVariance + movementDistance / 10_000`; choose the lowest score and break ties by lexicographic row counts.
10. Return placements in input token order and skip reasons sorted by token only when formatting debug output.

- [ ] **Step 4: Run layout tests and the complete suite**

Run: `swift test --filter LayoutEngineTests`

Expected: PASS, 4 tests.

Run: `swift test`

Expected: PASS, all tests.

- [ ] **Step 5: Commit the layout engine**

```bash
git add Sources/StepAsideCore/LayoutEngine.swift Tests/StepAsideCoreTests/LayoutEngineTests.swift
git commit -m "feat: add adaptive window layout engine"
```

### Task 3: Match visible Core Graphics windows to Accessibility windows

**Files:**
- Create: `Sources/StepAsideCore/WindowMatcher.swift`
- Create: `Tests/StepAsideCoreTests/WindowMatcherTests.swift`

**Interfaces:**
- Consumes: `Rect`.
- Produces: `CGWindowRecord`, `AXWindowRecord`, `WindowMatch`, and `WindowMatcher.match(cg:ax:)`.

- [ ] **Step 1: Write failing deterministic and ambiguity tests**

```swift
import XCTest
@testable import StepAsideCore

final class WindowMatcherTests: XCTestCase {
    func testMatchesDuplicateProcessWindowsByTitleAndBounds() {
        let cg = [
            CGWindowRecord(windowID: 41, pid: 7, title: "Alpha", frame: Rect(x: 0, y: 0, width: 800, height: 600)),
            CGWindowRecord(windowID: 42, pid: 7, title: "Beta", frame: Rect(x: 810, y: 0, width: 600, height: 600)),
        ]
        let ax = [
            AXWindowRecord(index: 0, pid: 7, title: "Beta", frame: Rect(x: 810, y: 0, width: 600, height: 600)),
            AXWindowRecord(index: 1, pid: 7, title: "Alpha", frame: Rect(x: 0, y: 0, width: 800, height: 600)),
        ]
        XCTAssertEqual(WindowMatcher().match(cg: cg, ax: ax), [
            WindowMatch(windowID: 41, axIndex: 1), WindowMatch(windowID: 42, axIndex: 0),
        ])
    }

    func testRejectsAnAmbiguousUntitledPair() {
        let cg = [CGWindowRecord(windowID: 1, pid: 9, title: "", frame: Rect(x: 0, y: 0, width: 500, height: 500))]
        let ax = [
            AXWindowRecord(index: 0, pid: 9, title: "", frame: Rect(x: 1, y: 0, width: 500, height: 500)),
            AXWindowRecord(index: 1, pid: 9, title: "", frame: Rect(x: 0, y: 1, width: 500, height: 500)),
        ]
        XCTAssertTrue(WindowMatcher().match(cg: cg, ax: ax).isEmpty)
    }
}
```

- [ ] **Step 2: Run the matcher tests and verify the undefined-type failure**

Run: `swift test --filter WindowMatcherTests`

Expected: FAIL because the record and matcher types are undefined.

- [ ] **Step 3: Implement scored one-to-one matching**

Create value types with the initializers shown in the tests and implement this scoring rule:

```swift
private func score(_ cg: CGWindowRecord, _ ax: AXWindowRecord) -> Double? {
    guard cg.pid == ax.pid else { return nil }
    let titlePenalty: Double
    if cg.title == ax.title { titlePenalty = cg.title.isEmpty ? 8 : 0 }
    else if cg.title.isEmpty || ax.title.isEmpty { titlePenalty = 25 }
    else { return nil }
    let edgeDelta = abs(cg.frame.minX - ax.frame.minX) + abs(cg.frame.minY - ax.frame.minY)
        + abs(cg.frame.width - ax.frame.width) + abs(cg.frame.height - ax.frame.height)
    guard edgeDelta <= 40 else { return nil }
    return titlePenalty + edgeDelta
}
```

For each Core Graphics record sorted by `windowID`, sort unused AX candidates by score then AX index. Accept the best candidate only when it is unique within 1 point of the second candidate. Return matches sorted by `windowID`.

- [ ] **Step 4: Run matcher and full tests**

Run: `swift test --filter WindowMatcherTests`

Expected: PASS, 2 tests.

Run: `swift test`

Expected: PASS.

- [ ] **Step 5: Commit the matcher**

```bash
git add Sources/StepAsideCore/WindowMatcher.swift Tests/StepAsideCoreTests/WindowMatcherTests.swift
git commit -m "feat: match visible and accessible windows"
```

### Task 4: Add serialized arrangement, verification, and Undo

**Files:**
- Create: `Sources/StepAsideCore/ArrangementCoordinator.swift`
- Create: `Tests/StepAsideCoreTests/ArrangementCoordinatorTests.swift`

**Interfaces:**
- Consumes: `DiscoverySnapshot`, `LayoutCalculating`, `WindowToken`, `Rect`, `LayoutResult`.
- Produces: `WindowSystem`, `ArrangementOutcome`, and actor `ArrangementCoordinator` with `arrange(spacing:)` and `undo()`.

- [ ] **Step 1: Write failing transaction tests with an actor fake**

```swift
import XCTest
@testable import StepAsideCore

final class ArrangementCoordinatorTests: XCTestCase {
    func testArrangeAppliesFramesAndUndoRestoresOriginals() async throws {
        let token = WindowToken(pid: 1, windowID: 1)
        let original = Rect(x: 50, y: 50, width: 800, height: 600)
        let system = FakeWindowSystem(window: WindowSnapshot(token: token, frame: original, displayID: 1))
        let coordinator = ArrangementCoordinator(windowSystem: system, layoutEngine: LayoutEngine())
        let arranged = await coordinator.arrange(spacing: 12)
        XCTAssertEqual(arranged.arrangedCount, 1)
        XCTAssertNotEqual(await system.currentFrame(token), original)
        let undone = await coordinator.undo()
        XCTAssertEqual(undone.restoredCount, 1)
        XCTAssertEqual(await system.currentFrame(token), original)
    }

    func testConcurrentArrangeReturnsBusy() async {
        let system = FakeWindowSystem(window: WindowSnapshot(token: .init(pid: 1, windowID: 1),
            frame: Rect(x: 0, y: 0, width: 800, height: 600), displayID: 1), applyDelayNanoseconds: 200_000_000)
        let coordinator = ArrangementCoordinator(windowSystem: system, layoutEngine: LayoutEngine())
        async let first = coordinator.arrange(spacing: 12)
        try? await Task.sleep(nanoseconds: 20_000_000)
        let second = await coordinator.arrange(spacing: 12)
        XCTAssertEqual(second.status, .busy)
        _ = await first
    }
}
```

The same file defines `FakeWindowSystem` as an actor implementing the production protocol. It returns one 1440×900 display, stores frames by token, optionally delays `setFrame`, and never touches AppKit.

- [ ] **Step 2: Run the coordinator tests and verify missing interfaces**

Run: `swift test --filter ArrangementCoordinatorTests`

Expected: FAIL because `WindowSystem`, `ArrangementOutcome`, and `ArrangementCoordinator` are undefined.

- [ ] **Step 3: Implement the actor and exact outcomes**

```swift
public protocol WindowSystem: Sendable {
    func discover() async throws -> DiscoverySnapshot
    func setFrame(_ frame: Rect, for token: WindowToken) async throws
    func frame(for token: WindowToken) async -> Rect?
}

public struct ArrangementOutcome: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case success, partial, noWindows, busy, failed, undone, nothingToUndo }
    public let status: Status
    public let arrangedCount: Int
    public let skippedCount: Int
    public let restoredCount: Int
    public init(status: Status, arrangedCount: Int, skippedCount: Int, restoredCount: Int) {
        self.status = status
        self.arrangedCount = arrangedCount
        self.skippedCount = skippedCount
        self.restoredCount = restoredCount
    }
}
```

`ArrangementCoordinator` is an actor. `arrange(spacing:)` guards `isRunning`, snapshots original frames, calls the layout engine, applies each placement, sleeps 80 ms, reads frames back, retries mismatches once, and returns `.partial` if any placement still differs by more than 2 pt on any edge. `undo()` restores the saved frames that still exist, clears the snapshot, and returns `.nothingToUndo` when empty. Every return path resets `isRunning` with `defer`.

- [ ] **Step 4: Run coordinator and full tests**

Run: `swift test --filter ArrangementCoordinatorTests`

Expected: PASS, 2 tests.

Run: `swift test`

Expected: PASS.

- [ ] **Step 5: Commit transaction behavior**

```bash
git add Sources/StepAsideCore/ArrangementCoordinator.swift Tests/StepAsideCoreTests/ArrangementCoordinatorTests.swift
git commit -m "feat: coordinate arrangement and undo"
```

### Task 5: Integrate public macOS window and system services

**Files:**
- Replace: `Sources/StepAside/StepAsideApplication.swift`
- Create: `Sources/StepAside/MacWindowSystem.swift`
- Create: `Sources/StepAside/AccessibilityGate.swift`
- Create: `Sources/StepAside/GlobalHotKeyService.swift`
- Create: `Sources/StepAside/LaunchAtLoginService.swift`
- Create: `Sources/StepAside/Preferences.swift`
- Create: `Tests/StepAsideCoreTests/PreferenceValueTests.swift`

**Interfaces:**
- Consumes: `WindowMatcher`, `WindowSystem`, `DiscoverySnapshot`, `Rect`.
- Produces: `MacWindowSystem`, `AccessibilityGate`, `GlobalHotKeyService`, `LaunchAtLoginService`, `SpacingPreference`, and `AppPreferences`.

- [ ] **Step 1: Add failing tests for spacing values and result-safe defaults**

```swift
import XCTest
@testable import StepAsideCore

final class PreferenceValueTests: XCTestCase {
    func testSpacingRawValuesAreStable() {
        XCTAssertEqual(SpacingPreference.compact.points, 8)
        XCTAssertEqual(SpacingPreference.balanced.points, 12)
        XCTAssertEqual(SpacingPreference.airy.points, 18)
        XCTAssertEqual(SpacingPreference(rawValue: "unknown") ?? .balanced, .balanced)
    }
}
```

Move `SpacingPreference` into `StepAsideCore/Models.swift` so the test target can validate it without loading AppKit.

- [ ] **Step 2: Run the test and confirm the missing preference failure**

Run: `swift test --filter PreferenceValueTests`

Expected: FAIL because `SpacingPreference` is undefined.

- [ ] **Step 3: Implement preferences and macOS service wrappers**

Implement `SpacingPreference: String, CaseIterable, Sendable` with cases `compact`, `balanced`, and `airy`, and the exact point values from the test. `AppPreferences` reads and writes `UserDefaults` keys `spacing`, `hotKeyKeyCode`, `hotKeyModifiers`, and `completedOnboarding`.

`AccessibilityGate` uses `AXIsProcessTrusted()` for status and `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` only after an explicit button or first Arrange action.

`GlobalHotKeyService` uses `RegisterEventHotKey` with default virtual key `kVK_ANSI_S` and modifiers `controlKey | optionKey`; it installs one application event handler and returns a typed conflict error when registration fails. It does not create a CG event tap.

`LaunchAtLoginService` wraps `SMAppService.mainApp.register()` and `.unregister()` and reflects `SMAppService.mainApp.status`.

`MacWindowSystem` is an actor with an internal `[WindowToken: AXUIElement]` map refreshed on every discovery. It must:

1. Call `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`.
2. Keep layer-zero, alpha-positive, non-StepAside windows at least 80×60 pt.
3. Query each owner's `kAXWindowsAttribute`, ordinary window role/subrole, minimized state, current position and size, and position/size settable flags.
4. Match metadata through `WindowMatcher`; ambiguous records are omitted.
5. Convert each `NSScreen.visibleFrame` to Core Graphics top-left coordinates using the matching `CGDisplayBounds` and the AppKit visible-frame insets.
6. Assign the display having the largest frame intersection.
7. Use reported minimum size when available and fall back to 160×120.
8. In `setFrame`, set AX size first and AX position second, throwing a typed error for each non-success `AXError`.
9. Never read `kAXValueAttribute`, text children, keyboard events, or screen pixels.

- [ ] **Step 4: Compile the app target and run all core tests**

Run: `swift build`

Expected: build completes with `Build complete!` and no private-symbol linker references.

Run: `swift test`

Expected: PASS.

Run: `nm -u .build/debug/StepAside | rg 'CGS|SLS|SkyLight'`

Expected: no output.

- [ ] **Step 5: Commit macOS integration**

```bash
git add Sources/StepAside Sources/StepAsideCore/Models.swift Tests/StepAsideCoreTests/PreferenceValueTests.swift
git commit -m "feat: integrate macOS window services"
```

### Task 6: Build the menu-bar interaction, onboarding, settings, and HUD

**Files:**
- Create: `Sources/StepAside/StatusItemController.swift`
- Create: `Sources/StepAside/HUDController.swift`
- Create: `Sources/StepAside/SettingsController.swift`
- Create: `Sources/StepAside/SettingsView.swift`
- Modify: `Sources/StepAside/StepAsideApplication.swift`
- Create: `Tests/StepAsideCoreTests/OutcomeCopyTests.swift`

**Interfaces:**
- Consumes: `ArrangementCoordinator`, `ArrangementOutcome`, `AccessibilityGate`, `AppPreferences`, hotkey and login services.
- Produces: a Dockless menu-bar lifecycle and user-visible result copy.

- [ ] **Step 1: Add failing tests for concise outcome copy**

```swift
import XCTest
@testable import StepAsideCore

final class OutcomeCopyTests: XCTestCase {
    func testSuccessAndPartialCopy() {
        XCTAssertEqual(ArrangementOutcome(status: .success, arrangedCount: 6, skippedCount: 0, restoredCount: 0).headline,
                       "6 windows · arranged")
        XCTAssertEqual(ArrangementOutcome(status: .partial, arrangedCount: 5, skippedCount: 2, restoredCount: 0).headline,
                       "5 arranged · 2 stayed")
        XCTAssertEqual(ArrangementOutcome(status: .undone, arrangedCount: 0, skippedCount: 0, restoredCount: 4).headline,
                       "4 windows · restored")
    }
}
```

- [ ] **Step 2: Run the copy test and confirm the missing property failure**

Run: `swift test --filter OutcomeCopyTests`

Expected: FAIL because `headline` is undefined.

- [ ] **Step 3: Add exact outcome copy and build AppKit controllers**

Add a `headline` computed property covering every `ArrangementOutcome.Status` without window titles.

`StatusItemController` creates a square `NSStatusItem`, uses a template `rectangle.grid.2x2` symbol until the custom menu template asset is ready, and calls `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`. Left mouse-up starts one `Task` that checks permission and calls `arrange(spacing:)`; right mouse-up opens an `NSMenu` containing the five approved commands. Arrange and Undo menu items update enabled state from coordinator outcomes.

`HUDController` creates an `NSPanel` with `.borderless` and `.nonactivatingPanel`, `level = .statusBar`, `collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]`, and a SwiftUI root view. It positions inside `NSScreen.main?.visibleFrame` at top right, uses yellow/blue/coral state bands, respects Reduce Motion, and closes after 2.2 seconds.

`SettingsController` owns one reusable titled settings window. `SettingsView` contains a large `STEP ASIDE.` heading, permission panel, three spacing choices, hotkey status, launch-at-login toggle, recent result, version, and no decorative web navigation. All controls have VoiceOver labels.

`StepAsideApplication` sets `.accessory` activation policy, constructs services once, installs the status item and hotkey, and opens onboarding when `completedOnboarding` is false or permission is missing.

- [ ] **Step 4: Compile, test, and launch the debug executable for a smoke check**

Run: `swift test`

Expected: PASS.

Run: `swift build`

Expected: build completes.

Run: `.build/debug/StepAside`

Expected: a StepAside status item appears, no Dock icon appears, and missing Accessibility permission opens onboarding. Stop the process with `Control-C` after inspection.

- [ ] **Step 5: Commit the complete interaction shell**

```bash
git add Sources Tests/StepAsideCoreTests/OutcomeCopyTests.swift
git commit -m "feat: add StepAside menu bar experience"
```

### Task 7: Create the original icon and reproducible release packages

**Files:**
- Create: `Brand/AppIcon-1024.png`
- Create: `Brand/AppIcon.iconset/*`
- Create: `Sources/StepAside/Resources/AppIcon.icns`
- Create: `Sources/StepAside/Resources/Info.plist`
- Create: `scripts/generate-icons.sh`
- Create: `scripts/build-app.sh`
- Create: `scripts/build-dmg.sh`
- Create: `Makefile`

**Interfaces:**
- Consumes: release executable and approved brand direction.
- Produces: `dist/StepAside.app` and `dist/StepAside.dmg`.

- [ ] **Step 1: Generate and inspect the 1024 px master icon**

Use the image-generation skill to create an original, realistic 3D macOS icon with dark window slabs moving outward into a precise tiled arrangement, warm ivory ground, and restrained yellow, pale-blue, and coral faces. Do not include text, letters, a copied logo, a browser frame, or a photograph. Inspect at 1024, 128, 32, and 16 px; use an edit pass if the silhouette collapses or fine detail becomes noise.

- [ ] **Step 2: Add deterministic icon and app packaging scripts**

`scripts/generate-icons.sh` must run with `set -euo pipefail`, require `Brand/AppIcon-1024.png` to be exactly 1024×1024, use `sips` to produce 16, 32, 64, 128, 256, 512, and 1024 pixel PNGs with Apple iconset filenames, and run `iconutil -c icns` into `Sources/StepAside/Resources/AppIcon.icns`.

`Sources/StepAside/Resources/Info.plist` must declare `CFBundleIdentifier` as `com.lawrenceriver.stepaside`, `CFBundleExecutable` as `StepAside`, `CFBundleIconFile` as `AppIcon`, `LSUIElement` as true, `LSMinimumSystemVersion` as `14.0`, and version `1.0.0`. Accessibility trust is requested through the system TCC prompt and does not use a fabricated plist privacy key.

`scripts/build-app.sh` must:

1. Run `swift build -c release`.
2. Recreate `dist/StepAside.app/Contents/{MacOS,Resources}`.
3. Copy the release executable, plist, and icon.
4. Sign with `${CODESIGN_IDENTITY:--}` using runtime options only for a non-ad-hoc identity.
5. Verify with `codesign --verify --deep --strict --verbose=2`.

`scripts/build-dmg.sh` must call `build-app.sh`, stage the app with an `/Applications` symlink, and run `hdiutil create -volname StepAside -srcfolder` to produce a compressed UDZO DMG.

- [ ] **Step 3: Build and validate the icon, app, and DMG**

Run: `bash scripts/generate-icons.sh`

Expected: `iconutil` creates a nonempty `AppIcon.icns`.

Run: `bash scripts/build-app.sh`

Expected: `dist/StepAside.app` passes strict ad-hoc code-sign verification.

Run: `bash scripts/build-dmg.sh`

Expected: `dist/StepAside.dmg` is created and `hdiutil verify dist/StepAside.dmg` succeeds.

- [ ] **Step 4: Inspect packaged metadata and executable imports**

Run: `plutil -lint dist/StepAside.app/Contents/Info.plist`

Expected: `OK`.

Run: `codesign -dvvv dist/StepAside.app 2>&1 | rg 'Identifier|Format|Signature'`

Expected: identifier `com.lawrenceriver.stepaside`, app bundle format, and ad-hoc signature.

Run: `nm -u dist/StepAside.app/Contents/MacOS/StepAside | rg 'CGS|SLS|SkyLight'`

Expected: no output.

- [ ] **Step 5: Commit brand and packaging assets**

```bash
git add Brand Sources/StepAside/Resources scripts Makefile
git commit -m "build: add StepAside branding and release packages"
```

### Task 8: Add public documentation, CI, and final release verification

**Files:**
- Create: `README.md`
- Create: `PRIVACY.md`
- Create: `ARCHITECTURE.md`
- Create: `CONTRIBUTING.md`
- Create: `CHANGELOG.md`
- Create: `RELEASE.md`
- Create: `LICENSE`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: tested app behavior and package commands.
- Produces: a clean, public-repository-ready project.

- [ ] **Step 1: Write repository documentation with exact supported behavior**

README must describe one-click current-Space arrangement, Undo, multiple displays, macOS 14+, Accessibility permission, installation from a DMG, `make test`, `make app`, and `make dmg`. It must explicitly say that StepAside does not record the screen, read window contents, manage inactive Spaces, or send data over the network.

`PRIVACY.md` must list the locally stored preference keys and confirm no telemetry or persistent window titles. `ARCHITECTURE.md` must document Core Graphics discovery, Accessibility mutation, coordinate conversion, matching ambiguity, layout invariants, and the no-private-API rule. `RELEASE.md` must separate the working ad-hoc build from the user-owned Developer ID, notarization, public repository creation, and GitHub push steps.

Use the MIT license and start `CHANGELOG.md` with version `1.0.0` dated 2026-07-16.

- [ ] **Step 2: Add CI with no release credentials**

```yaml
name: CI
on:
  push:
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Swift version
        run: swift --version
      - name: Build
        run: swift build
      - name: Test
        run: swift test
      - name: Package ad-hoc app
        run: bash scripts/build-app.sh
```

- [ ] **Step 3: Run the clean release gate**

Run: `rm -rf .build dist`

Run: `swift test`

Expected: all tests pass from a clean build.

Run: `make dmg`

Expected: app and verified DMG are recreated.

Run: `git status --short`

Expected: only intentional documentation and workflow files are untracked before staging; `.build` and `dist` remain ignored.

- [ ] **Step 4: Run manual acceptance and record results in `RELEASE.md`**

Launch the packaged app and verify permission onboarding, left-click arrangement, `Control-Option-S`, right-click menu, Undo, two-display preservation when available, partial handling for constrained windows, VoiceOver labels, Reduce Motion, and settings persistence. Record the date, macOS version, hardware architecture, tested apps, passed checks, and any reproducible platform limitation without including window titles or personal data.

- [ ] **Step 5: Commit public release material and tag the local candidate**

```bash
git add README.md PRIVACY.md ARCHITECTURE.md CONTRIBUTING.md CHANGELOG.md RELEASE.md LICENSE .github
git commit -m "docs: prepare StepAside for public release"
git tag -a v1.0.0-rc1 -m "StepAside 1.0.0 release candidate"
```

Run: `git status --short`

Expected: empty output.

Run: `git log --oneline --decorate -8`

Expected: the design, implementation, branding, packaging, and public-release commits are visible with `v1.0.0-rc1` on the final commit.
