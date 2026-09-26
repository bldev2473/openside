import Foundation
import CoreGraphics

/// Represents which edge of the main display a screen is attached to and where along that edge.
///
/// Remembering positions purely by coordinates shifts out of alignment when screen dimensions change.
/// Canvas sizes chosen by users differ from the iPad's native dimensions, and changing sizes alters bounds.
/// Recording the edge and ratio restores the screen to the intended relative position regardless of size changes.
///
/// The eight presets recalculate based on the target display's size.
/// This type provides the same property to custom manually-dragged positions.
public struct DisplayAnchor: Equatable, Sendable {

    /// Which edge of the main display the screen is attached to.
    public enum Edge: String, Sendable {
        case left
        case right
        case top
        case bottom
    }

    public let edge: Edge

    /// Position along that edge, representing the target screen center relative to the main display (0.0 to 1.0).
    /// Vertical for left/right edges, horizontal for top/bottom edges.
    public let ratio: Double

    public init(edge: Edge, ratio: Double) {
        self.edge = edge
        self.ratio = ratio
    }

    /// Derives an anchor from the current layout bounds.
    ///
    /// Compares the center offsets normalized by main display dimensions and selects the axis with greater deviation.
    /// Because displays do not overlap, one axis will always have a larger separation.
    public static func from(mainBounds: CGRect, targetBounds: CGRect) -> DisplayAnchor {
        let dx = (targetBounds.midX - mainBounds.midX) / max(mainBounds.width, 1)
        let dy = (targetBounds.midY - mainBounds.midY) / max(mainBounds.height, 1)

        let edge: Edge
        let ratio: Double
        if abs(dx) >= abs(dy) {
            edge = dx < 0 ? .left : .right
            ratio = (targetBounds.midY - mainBounds.minY) / max(mainBounds.height, 1)
        } else {
            edge = dy < 0 ? .top : .bottom
            ratio = (targetBounds.midX - mainBounds.minX) / max(mainBounds.width, 1)
        }

        return DisplayAnchor(edge: edge, ratio: ratio)
    }

    /// Computes the origin coordinates to position a display of targetBounds at this anchor.
    ///
    /// Places the attached edge flush against the main display and centers the remaining axis at the recorded ratio.
    public func origin(mainBounds: CGRect, targetBounds: CGRect) -> TargetDisplayOrigin {
        let alongY = mainBounds.minY + ratio * mainBounds.height - targetBounds.height / 2
        let alongX = mainBounds.minX + ratio * mainBounds.width - targetBounds.width / 2

        let x: Double
        let y: Double
        switch edge {
        case .left:
            x = mainBounds.minX - targetBounds.width
            y = alongY
        case .right:
            x = mainBounds.maxX
            y = alongY
        case .top:
            x = alongX
            y = mainBounds.minY - targetBounds.height
        case .bottom:
            x = alongX
            y = mainBounds.maxY
        }

        return TargetDisplayOrigin(x: Int32(round(x)), y: Int32(round(y)))
    }
}
