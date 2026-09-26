import Foundation

/// Reads and writes Sidecar screen display settings stored by macOS.
///
/// Corresponds to the settings surfaced in System Settings. Writing here produces consistent
/// behavior whether connected via Control Center or OpenSide, without diverging from System Settings.
public protocol SidecarSessionDefaultsManaging: Sendable {
    /// Whether the Touch Bar is displayed at the bottom of the iPad screen, or nil if unreadable.
    var showsTouchBar: Bool? { get }
    /// Whether the sidebar is displayed along the edge of the iPad screen, or nil if unreadable.
    var showsSidebar: Bool? { get }

    func setShowsTouchBar(_ show: Bool)
    func setShowsSidebar(_ show: Bool)
}

/// Reads and writes the `com.apple.sidecar.display` domain.
///
/// This domain is a user preference file located in `~/Library/Preferences` (owned by user, mode 600),
/// requiring no privilege escalation.
///
/// Preference keys are undocumented. If macOS changes key names, reads and writes would quietly fail without error;
/// therefore writes are verified by reading back.
///
/// Neither key exists in the file by default until explicitly modified by the user.
/// When absent, reads return nil, and macOS defaults to enabling both features.
public struct SystemSidecarSessionDefaults: SidecarSessionDefaultsManaging {
    private static let domain = "com.apple.sidecar.display" as CFString
    /// Note the lowercase 'b': reading "showTouchBar" returns nil.
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
