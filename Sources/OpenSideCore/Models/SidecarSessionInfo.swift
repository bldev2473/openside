import Foundation

/// Metrics for the currently running Sidecar session.
///
/// While `SidecarDisplayConfig` carries 22 values, only those with unambiguous semantics are included.
/// `transport`, `dataLink`, `cipher`, and `tilesPerFrame` contain only raw numbers without documented semantics.
/// Guessing names from numbers risks displaying silently incorrect descriptions if macOS changes internal representations.
public struct SidecarSessionInfo: Equatable, Sendable {
    /// Frames per second.
    public let framerate: Int
    /// Minimum bitrate bound (bit/s).
    public let minimumBitrate: Int
    /// Maximum bitrate bound (bit/s).
    public let maximumBitrate: Int
    /// Logical width used by the session.
    public let width: Int
    public let height: Int
    /// Pixel scale factor (2 for HiDPI).
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

    /// Bitrate formatted as "20 – 40 Mbps".
    public var bitrateText: String {
        let lower = minimumBitrate / 1_000_000
        let upper = maximumBitrate / 1_000_000
        return lower == upper ? "\(upper) Mbps" : "\(lower) – \(upper) Mbps"
    }

    /// Dimensions formatted as "1,112 × 834 (2×)".
    public var sizeText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let w = formatter.string(from: NSNumber(value: width)) ?? "\(width)"
        let h = formatter.string(from: NSNumber(value: height)) ?? "\(height)"
        return scale > 1 ? "\(w) × \(h) (\(scale)×)" : "\(w) × \(h)"
    }
}
