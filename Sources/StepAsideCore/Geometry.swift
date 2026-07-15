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
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func insetBy(dx: Double, dy: Double) -> Rect {
        Rect(
            x: x + dx,
            y: y + dy,
            width: max(0, width - dx * 2),
            height: max(0, height - dy * 2)
        )
    }

    public func expanded(by amount: Double) -> Rect {
        Rect(
            x: x - amount,
            y: y - amount,
            width: width + amount * 2,
            height: height + amount * 2
        )
    }

    public func intersection(_ other: Rect) -> Rect {
        let left = max(minX, other.minX)
        let top = max(minY, other.minY)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        guard right > left, bottom > top else { return .zero }
        return Rect(x: left, y: top, width: right - left, height: bottom - top)
    }

    public func contains(_ other: Rect, tolerance: Double = 0.5) -> Bool {
        other.minX >= minX - tolerance
            && other.minY >= minY - tolerance
            && other.maxX <= maxX + tolerance
            && other.maxY <= maxY + tolerance
    }

    public func distanceSquared(to other: Rect) -> Double {
        let dx = midX - other.midX
        let dy = midY - other.midY
        return dx * dx + dy * dy
    }
}
