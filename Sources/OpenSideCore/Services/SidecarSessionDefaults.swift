import Foundation

/// macOS 가 들고 있는 사이드카 화면 설정을 읽고 씁니다.
///
/// 시스템 설정 창이 보여주는 바로 그 값입니다. 여기에 쓰면 제어 센터로 붙이든 이 앱으로
/// 붙이든 같은 화면이 나오고, 시스템 설정 창과도 값이 어긋나지 않습니다.
public protocol SidecarSessionDefaultsManaging: Sendable {
    /// iPad 화면 아래의 Touch Bar 를 띄울지. 값을 못 읽으면 nil.
    var showsTouchBar: Bool? { get }
    /// iPad 화면 가장자리의 사이드바를 띄울지. 값을 못 읽으면 nil.
    var showsSidebar: Bool? { get }

    func setShowsTouchBar(_ show: Bool)
    func setShowsSidebar(_ show: Bool)
}

/// `com.apple.sidecar.display` 도메인을 읽고 씁니다.
///
/// 이 도메인은 사용자 홈의 자기 설정 파일입니다(`~/Library/Preferences`, 소유자 본인,
/// 권한 600). 권한 상승도 남의 데이터도 아닙니다.
///
/// 키 이름이 문서화되어 있지 않습니다. macOS 가 이름을 바꾸면 우리는 죽은 키를 읽고 쓰게
/// 되고, 오류 없이 조용히 아무 일도 안 일어납니다. 그래서 쓰기 뒤에 되읽어 확인합니다.
///
/// 두 키는 기본값일 때 파일에 없습니다. 사용자가 한 번이라도 바꿔야 생깁니다.
/// 없으면 nil 이고, 그때 macOS 의 기본값은 둘 다 켜짐입니다.
public struct SystemSidecarSessionDefaults: SidecarSessionDefaultsManaging {
    private static let domain = "com.apple.sidecar.display" as CFString
    /// b 가 소문자입니다. showTouchBar 로 읽으면 nil 이 나옵니다.
    private static let touchBarKey = "showTouchbar" as CFString
    private static let sidebarKey = "sidebarShown" as CFString

    public init() {}

    private func read(_ key: CFString) -> Bool? {
        CFPreferencesAppSynchronize(Self.domain)
        guard let value = CFPreferencesCopyValue(
            key, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) else {
            return nil
        }
        return (value as? NSNumber)?.boolValue
    }

    private func write(_ key: CFString, _ value: Bool) {
        CFPreferencesSetValue(
            key, value as CFBoolean, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        )
        CFPreferencesAppSynchronize(Self.domain)
    }

    public var showsTouchBar: Bool? { read(Self.touchBarKey) }
    public var showsSidebar: Bool? { read(Self.sidebarKey) }

    public func setShowsTouchBar(_ show: Bool) { write(Self.touchBarKey, show) }
    public func setShowsSidebar(_ show: Bool) { write(Self.sidebarKey, show) }
}
