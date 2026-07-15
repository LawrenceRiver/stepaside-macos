import Foundation

public enum SpacingPreference: String, CaseIterable, Equatable, Sendable {
    case compact
    case balanced
    case airy

    public var points: Double {
        switch self {
        case .compact: 8
        case .balanced: 12
        case .airy: 18
        }
    }
}

public struct WindowToken: Hashable, Codable, Sendable {
    public let pid: Int32
    public let windowID: UInt32

    public init(pid: Int32, windowID: UInt32) {
        self.pid = pid
        self.windowID = windowID
    }
}

public struct DisplaySnapshot: Equatable, Sendable {
    public let id: UInt32
    public let visibleFrame: Rect

    public init(id: UInt32, visibleFrame: Rect) {
        self.id = id
        self.visibleFrame = visibleFrame
    }
}

public struct WindowSnapshot: Equatable, Sendable {
    public let token: WindowToken
    public let frame: Rect
    public let displayID: UInt32
    public let minimumWidth: Double
    public let minimumHeight: Double
    public let isResizable: Bool

    public init(
        token: WindowToken,
        frame: Rect,
        displayID: UInt32,
        minimumWidth: Double = 160,
        minimumHeight: Double = 120,
        isResizable: Bool = true
    ) {
        self.token = token
        self.frame = frame
        self.displayID = displayID
        self.minimumWidth = minimumWidth
        self.minimumHeight = minimumHeight
        self.isResizable = isResizable
    }

    public var preferredAspectRatio: Double {
        min(4, max(0.25, frame.width / max(1, frame.height)))
    }
}

public struct Placement: Equatable, Sendable {
    public let token: WindowToken
    public let frame: Rect

    public init(token: WindowToken, frame: Rect) {
        self.token = token
        self.frame = frame
    }
}

public enum SkipReason: String, Equatable, Sendable {
    case ambiguousMatch
    case cannotMove
    case insufficientSpace
    case disappeared
    case rejectedFrame
}

public struct LayoutResult: Equatable, Sendable {
    public var placements: [Placement]
    public var skipped: [WindowToken: SkipReason]

    public init(
        placements: [Placement] = [],
        skipped: [WindowToken: SkipReason] = [:]
    ) {
        self.placements = placements
        self.skipped = skipped
    }
}

public struct DiscoverySnapshot: Equatable, Sendable {
    public let windows: [WindowSnapshot]
    public let displays: [DisplaySnapshot]

    public init(windows: [WindowSnapshot], displays: [DisplaySnapshot]) {
        self.windows = windows
        self.displays = displays
    }
}
