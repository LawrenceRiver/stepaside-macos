import Foundation

public enum DisplayGeometry {
    public static func coreGraphicsVisibleFrame(
        appKitFrame: Rect,
        appKitVisibleFrame: Rect,
        coreGraphicsBounds: Rect
    ) -> Rect {
        let leftInset = max(0, appKitVisibleFrame.minX - appKitFrame.minX)
        let rightInset = max(0, appKitFrame.maxX - appKitVisibleFrame.maxX)
        let bottomInset = max(0, appKitVisibleFrame.minY - appKitFrame.minY)
        let topInset = max(0, appKitFrame.maxY - appKitVisibleFrame.maxY)

        return Rect(
            x: coreGraphicsBounds.minX + leftInset,
            y: coreGraphicsBounds.minY + topInset,
            width: max(0, coreGraphicsBounds.width - leftInset - rightInset),
            height: max(0, coreGraphicsBounds.height - topInset - bottomInset)
        )
    }
}
