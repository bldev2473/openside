import Foundation
import CoreWLAN

/// Possible causes identified when Sidecar devices cannot be found
public enum SidecarReadinessIssue: String, Sendable, CaseIterable {
    case wifiOff
    case handoffOff

    /// System Settings pane URL to enable the relevant item. Used for shortcut buttons.
    ///
    /// Bundle IDs were verified against actual extensions installed under `/System/Library/ExtensionKit/Extensions/`.
    /// Passing non-existent IDs opens System Settings without error, masking bugs if incorrect.
    /// Re-verify against that path when changing.
    public var settingsURL: URL? {
        switch self {
        case .wifiOff:
            return URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")
        case .handoffOff:
            return URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension")
        }
    }
}

/// Interface for inspecting Sidecar connection prerequisites
public protocol SidecarReadinessChecking: Sendable {
    /// List of currently detected issues. If empty, prerequisites on this Mac are satisfied.
    func currentIssues() -> [SidecarReadinessIssue]
}

/// Implementation inspecting Sidecar prerequisites using system frameworks.
///
/// **Reads only this Mac's state**. There is no mechanism to query the iPad's state prior to connection.
///
/// Bluetooth power is not inspected. Reading via `IOBluetooth` requires Bluetooth permissions,
/// which is disproportionate for a layout utility and creates spurious warnings if denied.
///
/// Lock screen status, distance, Apple ID mismatch, and post-reboot Continuity discovery delays are also undetectable.
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

    /// While Apple documentation states Handoff is required for Sidecar, connections succeed
    /// even with Handoff disabled in empirical testing. Hence, this is surfaced as an advisory rather than a blocker.
    ///
    /// If settings have never been customized, the preference keys do not exist; absence of keys is treated
    /// as the default (enabled) state to avoid false positive warnings on pristine setups.
    private static func isHandoffEnabled() -> Bool {
        let domain = "com.apple.coreservices.useractivityd" as CFString

        // Users might toggle settings while the app is running; discard cache and re-read.
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
