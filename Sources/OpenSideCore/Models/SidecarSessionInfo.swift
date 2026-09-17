import Foundation

/// 지금 돌고 있는 사이드카 세션의 지표.
///
/// `SidecarDisplayConfig` 가 22개 값을 들고 있지만 뜻이 분명한 것만 담습니다.
/// `transport`, `dataLink`, `cipher`, `tilesPerFrame` 은 숫자만 있고 의미를 확인할
/// 방법이 없어 뺐습니다. 숫자를 보고 짐작해 이름을 붙이면 macOS 가 값을 바꿀 때
/// 조용히 틀린 설명을 하게 됩니다.
public struct SidecarSessionInfo: Equatable, Sendable {
    /// 초당 프레임 수.
    public let framerate: Int
    /// 전송률 하한(bit/s).
    public let minimumBitrate: Int
    /// 전송률 상한(bit/s).
    public let maximumBitrate: Int
    /// 세션이 쓰는 논리 크기.
    public let width: Int
    public let height: Int
    /// 픽셀 배율. 2 면 HiDPI 입니다.
    public let scale: Int
    public let isHDR: Bool

    public init(
        framerate: Int, minimumBitrate: Int, maximumBitrate: Int,
        width: Int, height: Int, scale: Int, isHDR: Bool
    ) {
        self.framerate = framerate
        self.minimumBitrate = minimumBitrate
        self.maximumBitrate = maximumBitrate
        self.width = width
        self.height = height
        self.scale = scale
        self.isHDR = isHDR
    }

    /// "20 – 40 Mbps" 처럼 읽히는 전송률.
    public var bitrateText: String {
        let lower = minimumBitrate / 1_000_000
        let upper = maximumBitrate / 1_000_000
        return lower == upper ? "\(upper) Mbps" : "\(lower) – \(upper) Mbps"
    }

    /// "1,112 × 834 (2배)" 처럼 읽히는 크기.
    public var sizeText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let w = formatter.string(from: NSNumber(value: width)) ?? "\(width)"
        let h = formatter.string(from: NSNumber(value: height)) ?? "\(height)"
        return scale > 1 ? "\(w) × \(h) (\(scale)×)" : "\(w) × \(h)"
    }
}
