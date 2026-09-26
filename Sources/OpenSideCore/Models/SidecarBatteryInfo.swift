import Foundation
import SwiftUI

/// Sidecar battery charging state
public enum SidecarBatteryState: String, Codable {
    case unknown
    case unplugged
    case charging
    case full
}

/// Battery percentage and charging status model for Sidecar devices
public struct SidecarBatteryInfo: Codable, Equatable {
    public let percentage: Int
    public let state: SidecarBatteryState
    public let updatedAt: Date

    public init(percentage: Int, state: SidecarBatteryState, updatedAt: Date = Date()) {
        self.percentage = max(0, min(100, percentage))
        self.state = state
        self.updatedAt = updatedAt
    }

    /// Whether the device is currently charging
    public var isCharging: Bool {
        state == .charging || state == .full
    }

    /// SF Symbols battery icon name
    public var iconName: String {
        if isCharging {
            return "battery.100.bolt"
        }
        switch percentage {
        case 0..<15:
            return "battery.0"
        case 15..<35:
            return "battery.25"
        case 35..<65:
            return "battery.50"
        case 65..<90:
            return "battery.75"
        default:
            return "battery.100"
        }
    }

    /// Visual accent color reflecting battery state
    public var iconColor: Color {
        if isCharging {
            return .green
        }
        if percentage <= 20 {
            return .red
        }
        return .secondary
    }
}
