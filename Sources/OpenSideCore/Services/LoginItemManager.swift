import Foundation
import ServiceManagement

/// Current status as a login item.
public enum LoginItemState: Equatable, Sendable {
    /// Not registered.
    case off
    /// Registered and runs at login.
    case on
    /// Registration accepted, but requires user approval in System Settings.
    ///
    /// macOS does not return an error in this state. Collapsing this to off would make the toggle
    /// revert to off immediately with no explanation.
    case needsApproval
}

/// Interface for controlling launch at login.
public protocol LoginItemManaging: Sendable {
    /// Current state. Queries the system directly rather than returning a cached value.
    var state: LoginItemState { get }

    /// Registers or unregisters the login item. Throws if rejected by the system.
    func setEnabled(_ enabled: Bool) throws
}

/// Implementation registering as a macOS login item via SMAppService.
///
/// Because users can toggle this in System Settings > General > Login Items, state is always
/// read from the system. Relying on local cached values risks divergence.
public struct SMAppServiceLoginItem: LoginItemManaging {
    public init() {}

    public var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        default: return .off
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// State observed by the 'Launch at login' toggle in Settings.
///
/// Does not assume registration succeeded. Re-queries the system after setting.
/// Unsigned builds may be rejected by the system; showing an active toggle in that case would be misleading.
@MainActor
public final class LoginItemToggle: ObservableObject {
    @Published public private(set) var state: LoginItemState

    /// Error description if the last attempt failed; cleared on success.
    @Published public private(set) var failure: String?

    /// Whether the toggle switch should be displayed as on. Pending approval is shown as on since registration was accepted.
    public var isOn: Bool { state != .off }

    /// Whether user approval is required in System Settings.
    public var needsApproval: Bool { state == .needsApproval }

    private let service: any LoginItemManaging

    public init(service: any LoginItemManaging = SMAppServiceLoginItem()) {
        self.service = service
        self.state = service.state
    }

    /// Re-reads system state when opening the window in case it changed in System Settings.
    public func refresh() {
        state = service.state
    }

    public func set(_ wanted: Bool) {
        do {
            try service.setEnabled(wanted)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
        state = service.state
    }
}
