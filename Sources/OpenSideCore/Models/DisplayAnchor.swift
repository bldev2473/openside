import Foundation
import CoreGraphics

/// 화면을 주 화면의 어느 변 어디쯤에 두었는지.
///
/// 좌표로 기억하면 화면 크기가 달라졌을 때 어긋납니다. 캔버스는 사용자가 고른 크기로 서므로
/// iPad 와 크기가 다르고, 크기를 바꾸면 또 달라집니다. 변과 비율로 적어 두면 크기와 무관하게
/// 같은 자리로 돌아옵니다.
///
/// 프리셋 여덟 칸은 이미 대상 크기로 다시 계산합니다. 이 타입은 손으로 끌어다 놓은 자리에
/// 같은 성질을 줍니다.
public struct DisplayAnchor: Equatable, Sendable {

    /// 주 화면의 어느 변에 붙어 있는지.
    public enum Edge: String, Sendable {
        case left
        case right
        case top
        case bottom
    }

    public let edge: Edge

    /// 그 변을 따라간 위치. 화면 중심이 주 화면의 어느 지점에 오는지를 0에서 1로 적습니다.
    /// 좌우 변이면 세로 방향, 위아래 변이면 가로 방향입니다.
    public let ratio: Double

    public init(edge: Edge, ratio: Double) {
        self.edge = edge
        self.ratio = ratio
    }

    /// 지금 놓인 자리에서 앵커를 읽습니다.
    ///
    /// 두 중심의 어긋남을 주 화면 크기로 나눠 비교하고, 더 크게 벗어난 축의 변을 고릅니다.
    /// 화면은 겹치지 않게 놓이므로 한쪽 축이 반드시 더 벌어져 있습니다.
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

    /// 주어진 크기의 화면을 이 앵커 자리에 세울 좌표를 냅니다.
    ///
    /// 붙는 변은 두 화면이 맞닿게 두고, 나머지 축은 중심이 비율 지점에 오도록 맞춥니다.
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
