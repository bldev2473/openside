import Foundation
import CoreGraphics

/// 디스플레이 기기 정보 모델
/// macOS 시스템에서 식별된 각 디스플레이의 식별자, 해상도, 좌표 및 사이드카 여부를 캡슐화합니다.
public struct DisplayInfo: Identifiable, Equatable, Sendable {
    /// CoreGraphics 고유 디스플레이 식별자
    public let id: CGDirectDisplayID
    /// 하드웨어 또는 가상 디스플레이의 영속적 UUID 문자열
    public let uuid: String
    /// 시스템에 등록된 디스플레이 이름 (예: "Built-in Retina Display", "Sidecar Display (AirPlay)")
    public let name: String
    /// 글로벌 CoreGraphics 좌표계 상의 위치 및 크기
    public let bounds: CGRect
    /// 주 디스플레이 (좌표 (0, 0) 기준 디스플레이) 여부
    public let isMain: Bool
    /// 내장 디스플레이 여부
    public let isBuiltin: Bool
    /// 아이패드 사이드카 디스플레이 여부
    public let isSidecar: Bool
    /// 이 디스플레이가 복제하고 있는 원본의 식별자. 복제 중이 아니면 nil.
    ///
    /// 복제 여부만으로는 부족합니다. 이 라이브러리를 쓰는 앱이 만든 캔버스를 비추는 것은 사용자가 보기에
    /// 확장이고, 메인 화면을 비추는 것은 복제입니다. 무엇을 복제하는지 알아야 그 둘을 가릅니다.
    public let mirrorSourceID: CGDirectDisplayID?

    /// 다른 디스플레이를 복제하고 있는지 여부.
    /// 복제 중에는 bounds 가 원본 디스플레이의 크기를 보고하므로 해상도로 읽으면 안 됩니다.
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

/// 사이드카 디스플레이 배치 프리셋 정의
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

/// 디스플레이 목표 좌표 모델
public struct TargetDisplayOrigin: Equatable, Sendable {
    public let x: Int32
    public let y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
}

/// 디스플레이 해상도 모드 모델
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

/// 사이드카 연결 대상 기기 정보 모델
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
