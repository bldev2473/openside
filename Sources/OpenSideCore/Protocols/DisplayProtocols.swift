import Foundation
import CoreGraphics

/// Interface for display detection
/// Enumerates active displays connected to the system and identifies Sidecar connections.
public protocol DisplayDetecting: Sendable {
    /// Returns all currently active displays.
    func getActiveDisplays() -> [DisplayInfo]

    /// Returns the connected Sidecar display, if present.
    func getSidecarDisplay() -> DisplayInfo?

    /// Returns the main display.
    func getMainDisplay() -> DisplayInfo?
}

/// Interface for calculating display arrangement coordinates
/// Computes global origin coordinates for presets based on main and target display dimensions.
public protocol ArrangementCalculating: Sendable {
    /// Calculates the target display's global origin (x, y) for a given preset.
    /// - Parameters:
    ///   - mainBounds: CGRect of the reference main display
    ///   - targetBounds: CGRect of the target display (Sidecar) being arranged
    ///   - preset: The arrangement preset to apply
    /// - Returns: Calculated target coordinates (x, y)
    func calculateOrigin(
        mainBounds: CGRect,
        targetBounds: CGRect,
        preset: DisplayArrangementPreset
    ) -> TargetDisplayOrigin
}

/// Interface for applying display configurations
/// Applies system display arrangements via CoreGraphics configuration transactions.
public protocol DisplayConfiguring: Sendable {
    /// Modifies and permanently commits the origin coordinates of a display.
    /// - Parameters:
    ///   - displayID: Target display ID
    ///   - origin: Target coordinates to configure
    /// - Returns: Success or configuration error
    func configureDisplayOrigin(
        displayID: CGDirectDisplayID,
        origin: TargetDisplayOrigin
    ) -> Result<Void, DisplayConfigurationError>

    /// Configures a display to mirror another display or cancels mirroring.
    /// - Parameters:
    ///   - displayID: Target display ID
    ///   - masterID: Master display ID to mirror. Passing nil reverts to extended display mode.
    ///   - persistence: How long the configuration should persist.
    func configureMirroring(
        displayID: CGDirectDisplayID,
        mirrorOf masterID: CGDirectDisplayID?,
        persistence: DisplayConfigurationPersistence
    ) -> Result<Void, DisplayConfigurationError>

    /// Returns whether the display is currently mirroring another display.
    func isMirroring(displayID: CGDirectDisplayID) -> Bool
}

/// Reports displays created by this application.
///
/// An app using this library may create a virtual display and mirror it to the iPad.
/// That virtual screen is also non-builtin and involved in mirroring, thus matching the detection rule unless filtered.
/// The creating component must report its identifier so it can be distinguished.
public protocol ManagedDisplayReporting: AnyObject, Sendable {
    /// The display created by this app, or nil if none.
    var managedDisplayID: CGDirectDisplayID? { get }
}

/// Component that controls canvas screen sizing. Injected by consuming apps, or nil if unused.
///
/// Canvases have a distinct list of selectable sizes. Resizing them also works differently —
/// rather than changing the display mode, the canvas is recreated at the new size.
/// Changing modes on virtual displays causes them to persist until process exit even after release.
/// Invoked only on the main actor alongside the view model.
@MainActor
public protocol CanvasSizing: AnyObject {
    /// Available canvas sizes.
    var availableCanvasSizes: [DisplayResolutionMode] { get }

    /// Current canvas size.
    var currentCanvasSize: DisplayResolutionMode? { get }

    /// Changes the canvas size by recreating the canvas.
    func selectCanvasSize(_ mode: DisplayResolutionMode)
}

/// Persistence duration for display configuration changes.
public enum DisplayConfigurationPersistence: Sendable {
    /// Reverts upon logout.
    case session
    /// Persists until explicitly changed again.
    case permanent
}

/// Errors that can occur during display configuration
public enum DisplayConfigurationError: Error, LocalizedError, Equatable {
    case beginConfigurationFailed(code: Int32)
    case configureOriginFailed(code: Int32)
    case completeConfigurationFailed(code: Int32)
    case configureMirroringFailed(code: Int32)

    /// Return code from CoreGraphics. Distinguishes the failure cause regardless of step.
    public var code: Int32 {
        switch self {
        case .beginConfigurationFailed(let code),
             .configureOriginFailed(let code),
             .completeConfigurationFailed(let code),
             .configureMirroringFailed(let code):
            return code
        }
    }

    /// English description for logging. User-facing strings are constructed separately by AppStrings per language.
    public var errorDescription: String? {
        switch self {
        case .beginConfigurationFailed(let code):
            return "Could not begin the display configuration (code \(code))"
        case .configureOriginFailed(let code):
            return "Could not move the display (code \(code))"
        case .completeConfigurationFailed(let code):
            return "Could not commit the display configuration (code \(code))"
        case .configureMirroringFailed(let code):
            return "Could not set up display mirroring (code \(code))"
        }
    }
}

/// Preset repository interface
/// Persists the user's recently selected arrangement presets and configurations.
public protocol PresetManaging: Sendable {
    /// Saves the last applied preset.
    func saveLastPreset(_ preset: DisplayArrangementPreset)

    /// Returns the last saved preset.
    func loadLastPreset() -> DisplayArrangementPreset?

    /// Clears the saved preset. Called when the user drags the display manually instead of choosing a preset.
    func clearLastPreset()
}

/// Interface for transforming miniature canvas drag coordinates into global system coordinates
public protocol CoordinateTransforming: Sendable {
    /// Calculates a new global origin based on canvas drag delta and scale.
    /// - Parameters:
    ///   - currentOrigin: Current global origin (x, y) of the target display
    ///   - dragTranslation: Mouse drag delta on canvas (dx, dy)
    ///   - scale: Downscaling ratio of miniature canvas relative to actual dimensions
    /// - Returns: Calculated new global target coordinates
    func transformDragToTargetOrigin(
        currentOrigin: CGPoint,
        dragTranslation: CGSize,
        scale: CGFloat
    ) -> TargetDisplayOrigin
}

/// Interface for enumerating and modifying display resolution modes
public protocol DisplayModeManaging: Sendable {
    /// Returns available distinct resolution modes for the display, sorted by dimensions.
    func getAvailableModes(displayID: CGDirectDisplayID) -> [DisplayResolutionMode]

    /// Returns the currently active resolution mode for the display.
    func getCurrentMode(displayID: CGDirectDisplayID) -> DisplayResolutionMode?

    /// Changes the display resolution mode.
    /// - Parameter persistence: How long the change should persist. Defaults to permanent.
    func setDisplayResolution(
        displayID: CGDirectDisplayID,
        mode: DisplayResolutionMode,
        persistence: DisplayConfigurationPersistence
    ) -> Result<Void, DisplayConfigurationError>

    /// Returns whether HiDPI can be toggled for the current resolution.
    func canToggleHiDPI(displayID: CGDirectDisplayID) -> Bool

    /// Toggles HiDPI on/off while maintaining the current logical resolution.
    func toggleHiDPI(displayID: CGDirectDisplayID, enable: Bool) -> Result<Void, DisplayConfigurationError>
}

/// Interface for discovering and connecting/disconnecting Sidecar devices
public protocol SidecarConnecting: Sendable {
    /// Returns nearby connectable Sidecar devices.
    func getAvailableDevices() -> [SidecarDeviceInfo]

    /// Initiates connection to the specified Sidecar device.
    func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void)

    /// Reads metrics of the currently running session, or nil if disconnected.
    func currentSessionInfo() -> SidecarSessionInfo?

    /// Terminates the active Sidecar session.
    func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}
