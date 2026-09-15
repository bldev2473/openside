import Foundation
import CoreGraphics

/// 미니어처 캔버스 드래그 변위 좌표를 실제 CoreGraphics 글로벌 좌표로 변환하는 변환기 구현체
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
