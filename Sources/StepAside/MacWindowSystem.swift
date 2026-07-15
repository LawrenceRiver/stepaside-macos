import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import StepAsideCore

actor MacWindowSystem: WindowSystem {
    enum SystemError: LocalizedError {
        case accessibility(AXError, String)
        case missingWindow(WindowToken)

        var errorDescription: String? {
            switch self {
            case let .accessibility(error, operation):
                "Accessibility failed while \(operation) (\(error.rawValue))."
            case .missingWindow:
                "The window is no longer available."
            }
        }
    }

    private struct Entry {
        let element: AXUIElement
        let isResizable: Bool
    }

    private struct AXCandidate {
        let record: AXWindowRecord
        let element: AXUIElement
        let isResizable: Bool
    }

    private struct ScreenMetadata: Sendable {
        let id: UInt32
        let frame: Rect
        let visibleFrame: Rect
        let coreGraphicsBounds: Rect
    }

    private let matcher = WindowMatcher()
    private var entries: [WindowToken: Entry] = [:]

    func discover() async throws -> DiscoverySnapshot {
        let screens = await Self.screenMetadata()
        let displays = screens.map {
            DisplaySnapshot(
                id: $0.id,
                visibleFrame: DisplayGeometry.coreGraphicsVisibleFrame(
                    appKitFrame: $0.frame,
                    appKitVisibleFrame: $0.visibleFrame,
                    coreGraphicsBounds: $0.coreGraphicsBounds
                )
            )
        }
        let cgRecords = Self.visibleWindowRecords(excludingPID: getpid())
        let groupedCG = Dictionary(grouping: cgRecords, by: \.pid)
        var discovered: [WindowSnapshot] = []
        var nextEntries: [WindowToken: Entry] = [:]

        for pid in groupedCG.keys.sorted() {
            let processRecords = groupedCG[pid] ?? []
            let candidates = Self.accessibilityCandidates(pid: pid)
            let matches = matcher.match(
                cg: processRecords,
                ax: candidates.map(\.record)
            )
            let candidateByIndex = Dictionary(uniqueKeysWithValues: candidates.map {
                ($0.record.index, $0)
            })
            let cgByID = Dictionary(uniqueKeysWithValues: processRecords.map { ($0.windowID, $0) })

            for match in matches {
                guard let candidate = candidateByIndex[match.axIndex],
                      let cgRecord = cgByID[match.windowID],
                      let display = Self.display(for: cgRecord.frame, in: screens),
                      !Self.isFullScreen(cgRecord.frame, on: display.coreGraphicsBounds) else { continue }

                let token = WindowToken(pid: pid, windowID: match.windowID)
                discovered.append(WindowSnapshot(
                    token: token,
                    frame: candidate.record.frame,
                    displayID: display.id,
                    minimumWidth: 160,
                    minimumHeight: 120,
                    isResizable: candidate.isResizable
                ))
                nextEntries[token] = Entry(
                    element: candidate.element,
                    isResizable: candidate.isResizable
                )
            }
        }

        entries = nextEntries
        return DiscoverySnapshot(
            windows: discovered.sorted { $0.token.windowID < $1.token.windowID },
            displays: displays
        )
    }

    func setFrame(_ frame: Rect, for token: WindowToken) async throws {
        guard let entry = entries[token] else { throw SystemError.missingWindow(token) }

        if entry.isResizable {
            var size = CGSize(width: frame.width, height: frame.height)
            guard let sizeValue = AXValueCreate(.cgSize, &size) else {
                throw SystemError.accessibility(.failure, "creating a size value")
            }
            let sizeError = AXUIElementSetAttributeValue(
                entry.element,
                kAXSizeAttribute as CFString,
                sizeValue
            )
            guard sizeError == .success else {
                throw SystemError.accessibility(sizeError, "resizing a window")
            }
        }

        var point = CGPoint(x: frame.x, y: frame.y)
        guard let pointValue = AXValueCreate(.cgPoint, &point) else {
            throw SystemError.accessibility(.failure, "creating a position value")
        }
        let positionError = AXUIElementSetAttributeValue(
            entry.element,
            kAXPositionAttribute as CFString,
            pointValue
        )
        guard positionError == .success else {
            throw SystemError.accessibility(positionError, "moving a window")
        }
    }

    func frame(for token: WindowToken) async -> Rect? {
        guard let entry = entries[token] else { return nil }
        return Self.frame(of: entry.element)
    }
}

private extension MacWindowSystem {
    @MainActor
    private static func screenMetadata() -> [ScreenMetadata] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            return ScreenMetadata(
                id: id,
                frame: Rect(screen.frame),
                visibleFrame: Rect(screen.visibleFrame),
                coreGraphicsBounds: Rect(CGDisplayBounds(id))
            )
        }
    }

    private static func visibleWindowRecords(excludingPID: pid_t) -> [CGWindowRecord] {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return raw.compactMap { dictionary in
            guard let windowID = dictionary[kCGWindowNumber as String] as? UInt32,
                  let ownerPID = dictionary[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != excludingPID,
                  (dictionary[kCGWindowLayer as String] as? Int ?? -1) == 0,
                  (dictionary[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let rawBounds = dictionary[kCGWindowBounds as String],
                  let bounds = rawBounds as? NSDictionary,
                  let cgRect = CGRect(dictionaryRepresentation: bounds),
                  cgRect.width >= 80,
                  cgRect.height >= 60 else { return nil }
            return CGWindowRecord(
                windowID: windowID,
                pid: ownerPID,
                title: dictionary[kCGWindowName as String] as? String ?? "",
                frame: Rect(cgRect)
            )
        }
    }

    private static func accessibilityCandidates(pid: Int32) -> [AXCandidate] {
        let application = AXUIElementCreateApplication(pid)
        guard let windowElements: [AXUIElement] = copyValue(
            application,
            attribute: kAXWindowsAttribute as CFString
        ) else { return [] }

        return windowElements.enumerated().compactMap { index, element in
            guard copyString(element, attribute: kAXRoleAttribute as CFString) == kAXWindowRole,
                  copyString(element, attribute: kAXSubroleAttribute as CFString) == kAXStandardWindowSubrole,
                  copyBool(element, attribute: kAXMinimizedAttribute as CFString) != true,
                  copyBool(element, attribute: kAXModalAttribute as CFString) != true,
                  let frame = frame(of: element),
                  isSettable(element, attribute: kAXPositionAttribute as CFString) else { return nil }

            return AXCandidate(
                record: AXWindowRecord(
                    index: index,
                    pid: pid,
                    title: copyString(element, attribute: kAXTitleAttribute as CFString) ?? "",
                    frame: frame
                ),
                element: element,
                isResizable: isSettable(element, attribute: kAXSizeAttribute as CFString)
            )
        }
    }

    private static func display(for frame: Rect, in screens: [ScreenMetadata]) -> ScreenMetadata? {
        screens.max { first, second in
            frame.intersection(first.coreGraphicsBounds).area
                < frame.intersection(second.coreGraphicsBounds).area
        }
    }

    static func isFullScreen(_ frame: Rect, on bounds: Rect) -> Bool {
        let covered = frame.intersection(bounds).area / max(1, bounds.area)
        return covered >= 0.98
            && abs(frame.width - bounds.width) <= 4
            && abs(frame.height - bounds.height) <= 4
    }

    static func frame(of element: AXUIElement) -> Rect? {
        guard let positionValue: AXValue = copyValue(
            element,
            attribute: kAXPositionAttribute as CFString
        ), let sizeValue: AXValue = copyValue(
            element,
            attribute: kAXSizeAttribute as CFString
        ), AXValueGetType(positionValue) == .cgPoint,
           AXValueGetType(sizeValue) == .cgSize else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return Rect(x: point.x, y: point.y, width: size.width, height: size.height)
    }

    static func copyString(_ element: AXUIElement, attribute: CFString) -> String? {
        copyValue(element, attribute: attribute)
    }

    static func copyBool(_ element: AXUIElement, attribute: CFString) -> Bool? {
        copyValue(element, attribute: attribute)
    }

    static func copyValue<T>(_ element: AXUIElement, attribute: CFString) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? T
    }

    static func isSettable(_ element: AXUIElement, attribute: CFString) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success
            && settable.boolValue
    }
}

private extension Rect {
    init(_ rectangle: CGRect) {
        self.init(
            x: rectangle.origin.x,
            y: rectangle.origin.y,
            width: rectangle.size.width,
            height: rectangle.size.height
        )
    }
}
