import Foundation
import CoreWLAN

/// 사이드카 기기를 찾지 못했을 때 짚어줄 수 있는 원인
public enum SidecarReadinessIssue: String, Sendable, CaseIterable {
    case wifiOff
    case handoffOff

    /// 해당 항목을 켤 수 있는 시스템 설정 화면. 바로가기 버튼에 사용합니다.
    ///
    /// 번들 ID 는 `/System/Library/ExtensionKit/Extensions/` 에 설치된 실제 확장에서 확인한 값입니다.
    /// 존재하지 않는 ID 를 넘겨도 설정 앱은 그냥 열리므로(오류가 나지 않음) 값이 틀려도
    /// 티가 나지 않습니다. 바꿀 때는 위 경로에서 다시 확인할 것.
    public var settingsURL: URL? {
        switch self {
        case .wifiOff:
            return URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")
        case .handoffOff:
            return URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension")
        }
    }
}

/// 사이드카 연결 전제 조건 점검 인터페이스
public protocol SidecarReadinessChecking: Sendable {
    /// 현재 확인 가능한 문제 목록. 비어 있으면 Mac 쪽 전제 조건은 충족된 상태입니다.
    func currentIssues() -> [SidecarReadinessIssue]
}

/// 시스템 프레임워크로 사이드카 전제 조건을 점검하는 구현체.
///
/// **이 Mac 의 상태만** 읽습니다. 연결 전에는 iPad 상태를 물어볼 수단이 없습니다.
///
/// Bluetooth 전원은 점검하지 않습니다. `IOBluetooth` 로 읽으려면 Bluetooth 권한이 필요한데,
/// 배치 도구가 요구하기엔 과하고 거부당하면 오히려 잘못된 경고를 띄우게 됩니다.
///
/// iPad 잠금 상태, 거리, Apple ID 불일치, 재부팅 직후 Continuity 탐색 지연도 감지할 수 없습니다.
public struct SystemSidecarReadinessChecker: SidecarReadinessChecking {
    public init() {}

    public func currentIssues() -> [SidecarReadinessIssue] {
        var issues: [SidecarReadinessIssue] = []

        if let interface = CWWiFiClient.shared().interface(), !interface.powerOn() {
            issues.append(.wifiOff)
        }

        if !Self.isHandoffEnabled() {
            issues.append(.handoffOff)
        }

        return issues
    }

    /// Apple 문서는 사이드카에 Handoff 가 필요하다고 하지만, 꺼져 있어도 연결되는 것을
    /// 실측으로 확인했다. 그래서 연결을 막는 조건이 아니라 참고용으로 알린다.
    ///
    /// 설정을 한 번도 건드리지 않으면 키 자체가 없으므로, 값이 없을 때는 기본값인 켜짐으로
    /// 본다. 그래야 멀쩡한 환경에 잘못된 경고를 띄우지 않는다.
    private static func isHandoffEnabled() -> Bool {
        let domain = "com.apple.coreservices.useractivityd" as CFString

        // 앱이 떠 있는 동안 사용자가 설정을 바꿀 수 있으므로 캐시를 버리고 다시 읽는다.
        CFPreferencesAppSynchronize(domain)

        for key in ["ActivityAdvertisingAllowed", "ActivityReceivingAllowed"] {
            let value = CFPreferencesCopyValue(
                key as CFString,
                domain,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            )
            if let enabled = value as? Bool, !enabled {
                return false
            }
        }

        return true
    }
}
