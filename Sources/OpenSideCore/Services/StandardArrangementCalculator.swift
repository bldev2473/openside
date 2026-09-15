import Foundation
import CoreGraphics

/// 표준 디스플레이 정렬 좌표 계산기 구현체
/// 주 디스플레이의 해상도와 사이드카 디스플레이의 해상도를 바탕으로
/// CoreGraphics 글로벌 좌표계 기준의 x, y 위치를 정확하게 산출합니다.
public struct StandardArrangementCalculator: ArrangementCalculating {
    public init() {}

    public func calculateOrigin(
        mainBounds: CGRect,
        targetBounds: CGRect,
        preset: DisplayArrangementPreset
    ) -> TargetDisplayOrigin {
        let mainWidth = mainBounds.width
        let mainHeight = mainBounds.height
        let targetWidth = targetBounds.width
        let targetHeight = targetBounds.height

        let x: Double
        let y: Double

        switch preset {
        case .leftTop:
            x = -targetWidth
            y = 0

        case .leftCenter:
            x = -targetWidth
            y = (mainHeight - targetHeight) / 2.0

        case .leftBottom:
            x = -targetWidth
            y = mainHeight - targetHeight

        case .rightTop:
            x = mainWidth
            y = 0

        case .rightCenter:
            x = mainWidth
            y = (mainHeight - targetHeight) / 2.0

        case .rightBottom:
            x = mainWidth
            y = mainHeight - targetHeight

        case .topCenter:
            x = (mainWidth - targetWidth) / 2.0
            y = -targetHeight

        case .bottomCenter:
            x = (mainWidth - targetWidth) / 2.0
            y = mainHeight
        }

        return TargetDisplayOrigin(
            x: Int32(round(x)),
            y: Int32(round(y))
        )
    }
}
