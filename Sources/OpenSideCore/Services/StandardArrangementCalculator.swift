import Foundation
import CoreGraphics

/// Standard display arrangement origin calculator
/// Computes precise global CoreGraphics (x, y) coordinates for each preset
/// given the bounding boxes of the main and Sidecar displays.
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
