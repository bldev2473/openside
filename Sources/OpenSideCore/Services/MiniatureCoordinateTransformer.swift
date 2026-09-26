import Foundation
import CoreGraphics

/// Coordinate transformer converting miniature canvas drag translations to global CoreGraphics coordinates
public struct MiniatureCoordinateTransformer: CoordinateTransforming {
    public init() {}

    public func transformDragToTargetOrigin(
        currentOrigin: CGPoint,
        dragTranslation: CGSize,
        scale: CGFloat
    ) -> TargetDisplayOrigin {
        guard scale > 0 else {
            return TargetDisplayOrigin(
                x: Int32(round(currentOrigin.x)),
                y: Int32(round(currentOrigin.y))
            )
        }

        let deltaX = dragTranslation.width / scale
        let deltaY = dragTranslation.height / scale

        let newX = currentOrigin.x + deltaX
        let newY = currentOrigin.y + deltaY

        return TargetDisplayOrigin(
            x: Int32(round(newX)),
            y: Int32(round(newY))
        )
    }
}
