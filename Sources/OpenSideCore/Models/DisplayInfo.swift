import Foundation
import CoreGraphics

/// Display device info model
/// Encapsulates identifier, resolution, coordinates, and Sidecar status for each display recognized by macOS.
public struct DisplayInfo: Identifiable, Equatable, Sendable {
    /// CoreGraphics display identifier
    public let id: CGDirectDisplayID
    /// Persistent UUID string for hardware or virtual display
    public let uuid: String
    /// Display name registered with the system (e.g., "Built-in Retina Display", "Sidecar Display (AirPlay)")
    public let name: String
    /// Frame bounds in global CoreGraphics coordinate space
    public let bounds: CGRect
    /// Whether this is the main display (origin at (0, 0))
    public let isMain: Bool
    /// Whether this is the built-in display
    public let isBuiltin: Bool
    /// Whether this is an iPad Sidecar display
    public let isSidecar: Bool
    /// ID of the source display being mirrored, or nil if not mirroring.
    ///
    /// Checking isMirrored alone is insufficient. Mirroring an app-created canvas is perceived by users
    /// as extending, whereas mirroring the main screen is mirroring. Knowing what is being mirrored distinguishes the two.
    public let mirrorSourceID: CGDirectDisplayID?

    /// Whether this display is mirroring another display.
    /// During mirroring, bounds reports the source display's dimensions, so it should not be read as physical resolution.
    public var isMirrored: Bool { mirrorSourceID != nil }

    public init(
        id: CGDirectDisplayID,
        uuid: String,
        name: String,
        bounds: CGRect,
        isMain: Bool,
        isBuiltin: Bool,
        isSidecar: Bool,
        mirrorSourceID: CGDirectDisplayID? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.bounds = bounds
        self.isMain = isMain
        self.isBuiltin = isBuiltin
        self.isSidecar = isSidecar
        self.mirrorSourceID = mirrorSourceID
    }
}

/// Arrangement presets for Sidecar display
public enum DisplayArrangementPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case leftTop
    case leftCenter
    case leftBottom
    case rightTop
    case rightCenter
    case rightBottom
    case topCenter
    case bottomCenter

    public var id: String { rawValue }
}

/// Target display origin coordinates model
public struct TargetDisplayOrigin: Equatable, Sendable {
    public let x: Int32
    public let y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
}

/// Display resolution mode model
public struct DisplayResolutionMode: Identifiable, Equatable, Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let refreshRate: Double
    public let isHiDPI: Bool
    public let isCurrent: Bool

    public var id: String {
        "\(width)x\(height)_\(pixelWidth)x\(pixelHeight)_\(Int(refreshRate))"
    }

    public var formattedText: String {
        if isHiDPI {
            return "\(width) × \(height) (HiDPI)"
        } else {
            return "\(width) × \(height)"
        }
    }

    public init(
        width: Int,
        height: Int,
        pixelWidth: Int,
        pixelHeight: Int,
        refreshRate: Double,
        isHiDPI: Bool,
        isCurrent: Bool = false
    ) {
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
        self.isHiDPI = isHiDPI
        self.isCurrent = isCurrent
    }
}

/// Sidecar connectable target device info model
public struct SidecarDeviceInfo: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let isConnected: Bool

    public init(id: String, name: String, isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
    }
}
