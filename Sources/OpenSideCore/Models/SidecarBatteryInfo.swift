import Foundation
import SwiftUI

/// 사이드카 배터리 충전 상태
public enum SidecarBatteryState: String, Codable {
    case unknown
    case unplugged
    case charging
    case full
}

/// 사이드카 기기의 배터리 잔량 및 충전 상태 모델
public struct SidecarBatteryInfo: Codable, Equatable {
    public let percentage: Int
    public let state: SidecarBatteryState
    public let updatedAt: Date

    public init(percentage: Int, state: SidecarBatteryState, updatedAt: Date = Date()) {
        self.percentage = max(0, min(100, percentage))
        self.state = state
        self.updatedAt = updatedAt
    }

    /// 현재 기기가 충전 중인지 여부
    public var isCharging: Bool {
        state == .charging || state == .full
    }

    /// SF Symbols 배터리 아이콘 이름
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

    /// 배터리 상태에 따른 시각적 강조 색상
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
