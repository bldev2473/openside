import Foundation
import SwiftUI
import Combine
import CoreGraphics

/// Main view model overseeing Sidecar state and display arrangement control.
@MainActor
public final class DisplayManagerViewModel: ObservableObject {
    @Published public private(set) var displays: [DisplayInfo] = []
    @Published public private(set) var mainDisplay: DisplayInfo?
    @Published public private(set) var sidecarDisplay: DisplayInfo?
    @Published public private(set) var isSidecarConnected: Bool = false
    @Published public private(set) var lastAppliedPreset: DisplayArrangementPreset?
    @Published public private(set) var availableResolutions: [DisplayResolutionMode] = []
    @Published public private(set) var currentResolution: DisplayResolutionMode?
    @Published public private(set) var isCurrentResolutionHiDPI: Bool = false
    @Published public private(set) var canToggleHiDPI: Bool = false
    /// Whether the iPad is mirroring the main display. Arrangement is meaningless during mirroring.
    @Published public private(set) var isSidecarMirrored: Bool = false
    /// Whether the iPad is mirroring the virtual canvas created by this app. In this case, resolution is determined by the canvas.
    @Published public private(set) var isShowingCanvas: Bool = false
    /// Selectable sizes while mirroring the canvas. Empty otherwise.
    @Published public private(set) var availableCanvasSizes: [DisplayResolutionMode] = []
    /// Current size used by the canvas.
    @Published public private(set) var currentCanvasSize: DisplayResolutionMode?
    /// Metrics of the currently running session. nil if disconnected.
    @Published public private(set) var sessionInfo: SidecarSessionInfo?
    /// Selectable resolutions for the main display. Populated only during mirroring.
    ///
    /// During mirroring, both displays share a single resolution determined by the main display. Changing
    /// mode on the iPad only causes reported values to diverge while the actual rendered output remains unchanged.
    /// To change the resolution, the main display mode must be changed.
    @Published public private(set) var availableMainResolutions: [DisplayResolutionMode] = []
    @Published public private(set) var availableSidecarDevices: [SidecarDeviceInfo] = []
    /// Verified cause on Mac side when devices could not be found. Empty if devices are found.
    @Published public private(set) var readinessIssues: [SidecarReadinessIssue] = []
    @Published public private(set) var sidecarBattery: SidecarBatteryInfo?
    /// Estimated remaining operating time in seconds with current battery level. nil if no estimator implementation or insufficient samples.
    @Published public private(set) var remainingEstimate: TimeInterval?
    @Published public private(set) var isConnecting: Bool = false
    /// Last device that failed to connect. Not displayed on screen.
    /// Used as a flag to prevent auto-connect from repeating the same failure on the same device.
    @Published public private(set) var lastConnectFailure: SidecarDeviceInfo?
    /// Last device that connected successfully. Not displayed on screen.
    /// Auto-connect learns which device to prioritize from this.
    @Published public private(set) var lastConnectedDevice: SidecarDeviceInfo?
    /// Reason for the last failed operation. Stored as an enum category rather than a formatted string, allowing UI to render in the selected language.
    @Published public private(set) var failure: DisplayOperationFailure?

    /// Records rejection by CoreGraphics.
    ///
    /// Preserves the error type directly so the UI can construct a localized message. If opened as a generic Error,
    /// type info is lost and untranslated English strings may reach the screen without compiler safety.
    private func record(_ error: DisplayConfigurationError) {
        failure = .configuration(error)
    }

    private let detector: DisplayDetecting
    private let calculator: ArrangementCalculating
    private let configurator: DisplayConfiguring
    private let presetManager: PresetManaging
    private let modeManager: DisplayModeManaging
    private let sidecarConnector: SidecarConnecting
    private let readinessChecker: SidecarReadinessChecking
    private let batteryReceiver: BatteryReceiving?
    /// Provider reporting displays managed by this app. Injected by the consumer app; nil if omitted.
    private let managedDisplays: ManagedDisplayReporting?
    /// Provider determining canvas sizing. Injected by the consumer app; nil if omitted.
    private let canvasSizing: CanvasSizing?
    private let remainingTimeEstimator: RemainingTimeEstimating?

    private var screenNotificationObserver: NSObjectProtocol?

    public init(
        detector: DisplayDetecting = CoreGraphicsDisplayDetector(),
        calculator: ArrangementCalculating = StandardArrangementCalculator(),
        configurator: DisplayConfiguring = CoreGraphicsDisplayConfigurator(),
        presetManager: PresetManaging = UserDefaultsPresetManager(),
        modeManager: DisplayModeManaging = CoreGraphicsDisplayModeManager(),
        sidecarConnector: SidecarConnecting = SidecarDeviceManager(),
        readinessChecker: SidecarReadinessChecking = SystemSidecarReadinessChecker(),
        // Battery query implementation is injected by the consumer app. If omitted, no battery badge is displayed.
        batteryReceiver: BatteryReceiving? = nil,
        // Remaining time estimator is also injected by the consumer app.
        remainingTimeEstimator: RemainingTimeEstimating? = nil,
        // Displays managed by this app are also injected by the consumer app.
        managedDisplays: ManagedDisplayReporting? = nil,
        // Canvas size list is also injected by the consumer app.
        canvasSizing: CanvasSizing? = nil
    ) {
        self.detector = detector
        self.calculator = calculator
        self.configurator = configurator
        self.presetManager = presetManager
        self.modeManager = modeManager
        self.sidecarConnector = sidecarConnector
        self.readinessChecker = readinessChecker
        self.batteryReceiver = batteryReceiver
        self.remainingTimeEstimator = remainingTimeEstimator
        self.managedDisplays = managedDisplays
        self.canvasSizing = canvasSizing
        self.lastAppliedPreset = presetManager.loadLastPreset()

        setupBatteryReceiver()
        refreshDisplays()
        setupScreenChangeObserver()
    }

    deinit {
        batteryReceiver?.stopListening()
        // The receiver may be injected as a singleton. Leaving the callback attached would retain
        // a dead closure even after this view model is deallocated.
        batteryReceiver?.onBatteryUpdate = nil
        if let observer = screenNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Registers the battery receiver listener and performs data binding.
    private func setupBatteryReceiver() {
        batteryReceiver?.onBatteryUpdate = { [weak self] battery in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sidecarBattery = battery

                // Estimation is meaningless if iPad battery cannot be read.
                guard let battery else {
                    self.remainingEstimate = nil
                    return
                }
                // Recalculates upon every value update as estimation changes with history accumulation.
                self.remainingEstimate = self.remainingTimeEstimator?
                    .estimatedRemaining(currentBattery: battery.percentage)
            }
        }
        batteryReceiver?.startListening()
    }

    /// Registers screen parameter change notification observer.
    private func setupScreenChangeObserver() {
        screenNotificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplays()
            }
        }
    }

    /// Refreshes display state after a mode change has propagated to the system.
    ///
    /// Resolution changes are not instantaneous. Measurements showed up to 0.48s during mirroring.
    /// Reading only once after 0.2s previously left stale values on screen.
    /// Reading twice ensures slow devices are properly captured by the second refresh even if the first is early.
    private func refreshAfterModeChange() {
        for delay in [0.6, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refreshDisplays()
            }
        }
    }

    /// Refreshes current system display state.
    public func refreshDisplays() {
        let activeDisplays = detector.getActiveDisplays()
        self.displays = activeDisplays
        self.mainDisplay = detector.getMainDisplay()
        self.sidecarDisplay = detector.getSidecarDisplay()
        self.isSidecarConnected = (self.sidecarDisplay != nil)

        // iPad mirroring a canvas is not treated as standard mirroring; the desktop extends to the canvas
        // and iPad merely mirrors that canvas copy. Only mirroring the main display is treated as mirroring.
        // Active preset indicator is derived from the actual layout. Restoring from saved preset alone
        // would leave an incorrect indicator active if moved via System Settings or another build.
        self.lastAppliedPreset = self.presetMatchingLayout()

        self.isShowingCanvas = self.isSidecarShowingCanvas
        // Canvas determines size while mirroring it; iPad's own mode list is not applicable.
        self.availableCanvasSizes = self.isShowingCanvas ? (canvasSizing?.availableCanvasSizes ?? []) : []
        self.currentCanvasSize = self.isShowingCanvas ? canvasSizing?.currentCanvasSize : nil
        self.isSidecarMirrored = (self.sidecarDisplay?.isMirrored ?? false) && !self.isShowingCanvas

        if self.isSidecarMirrored, let main = self.mainDisplay {
            self.availableMainResolutions = modeManager.getAvailableModes(displayID: main.id)
        } else {
            self.availableMainResolutions = []
        }

        if let sidecar = self.sidecarDisplay {
            self.availableResolutions = modeManager.getAvailableModes(displayID: sidecar.id)
            let curr = modeManager.getCurrentMode(displayID: sidecar.id)
            self.currentResolution = curr
            self.isCurrentResolutionHiDPI = curr?.isHiDPI ?? false
            self.canToggleHiDPI = modeManager.canToggleHiDPI(displayID: sidecar.id)
        } else {
            self.availableResolutions = []
            self.currentResolution = nil
            self.isCurrentResolutionHiDPI = false
            self.canToggleHiDPI = false
        }

        self.availableSidecarDevices = sidecarConnector.getAvailableDevices()
        self.sessionInfo = self.isSidecarConnected ? sidecarConnector.currentSessionInfo() : nil
        // Always check readiness issues because connection will fail if prerequisites are broken even if devices remain listed.
        self.readinessIssues = self.isSidecarConnected ? [] : readinessChecker.currentIssues()
        self.failure = nil
    }

    /// Preset exactly matching the current arrangement. nil if none match (custom positioned).
    private func presetMatchingLayout() -> DisplayArrangementPreset? {
        guard let main = mainDisplay, let target = arrangementTarget else { return nil }

        return DisplayArrangementPreset.allCases.first { preset in
            let wanted = calculator.calculateOrigin(
                mainBounds: main.bounds,
                targetBounds: target.bounds,
                preset: preset
            )
            return Int32(target.bounds.origin.x.rounded()) == wanted.x
                && Int32(target.bounds.origin.y.rounded()) == wanted.y
        }
    }

    /// Whether iPad is mirroring the canvas created by this app.
    ///
    /// The canvas existing alone is insufficient; if the user reverts to extension,
    /// the canvas may remain but is no longer linked to iPad.
    private var isSidecarShowingCanvas: Bool {
        guard let managedID = managedDisplays?.managedDisplayID else { return false }
        return sidecarDisplay?.mirrorSourceID == managedID
    }

    /// Target display to apply arrangement to.
    ///
    /// While iPad is mirroring a canvas, desktop extension occurs on the canvas. iPad merely displays
    /// a replica, so moving iPad has no effect. Once mirroring is disabled, iPad is the target even if canvas exists.
    private var arrangementTarget: DisplayInfo? {
        if isSidecarShowingCanvas,
           let managedID = managedDisplays?.managedDisplayID,
           let canvas = displays.first(where: { $0.id == managedID }) {
            return canvas
        }
        return sidecarDisplay
    }

    /// Refreshes only available devices without touching display configuration.
    ///
    /// `refreshDisplays()` re-enumerates displays and rebuilds resolution lists, which is unnecessary
    /// for frequent background polling. This only reads the array already held by SidecarCore (~0.0011 ms per call).
    public func refreshSidecarDevices() {
        self.availableSidecarDevices = sidecarConnector.getAvailableDevices()
    }

    /// Changes canvas size, recreating the canvas at the specified size.
    public func changeCanvasSize(_ mode: DisplayResolutionMode) {
        canvasSizing?.selectCanvasSize(mode)
        refreshAfterModeChange()
    }

    /// Toggles HiDPI mode at the current resolution.
    public func toggleHiDPI(_ enabled: Bool) {
        guard let sidecar = sidecarDisplay else { return }
        let result = modeManager.toggleHiDPI(displayID: sidecar.id, enable: enabled)
        switch result {
        case .success:
            self.isCurrentResolutionHiDPI = enabled
            self.failure = nil
            refreshAfterModeChange()
        case .failure(let error):
            self.record(error)
        }
    }

    /// Configures iPad to mirror the specified display. Disables mirroring if nil.
    ///
    /// `toggleMirroring` targets the main display only. This method is used when mirroring to other displays
    /// such as an app-created canvas.
    /// - Parameter anchor: Position to place the master display after configuring mirroring. Moving it later
    ///   would briefly show macOS's default position on iPad, so it is handled within the same call.
    @discardableResult
    public func mirrorSidecar(
        onto masterID: CGDirectDisplayID?,
        placing anchor: DisplayAnchor? = nil
    ) -> Bool {
        guard let sidecar = sidecarDisplay else {
            failure = .noSidecarDisplay
            return false
        }

        switch configurator.configureMirroring(displayID: sidecar.id, mirrorOf: masterID, persistence: .session) {
        case .success:
            self.failure = nil
            // Since display list is not yet updated, arrangementTarget cannot be trusted.
            // Pin target explicitly to the master display just configured.
            if let anchor, let master = masterID,
               let target = displays.first(where: { $0.id == master }) {
                applyArrangement(anchor, to: target)
            }
            refreshAfterModeChange()
            return true
        case .failure(let error):
            self.record(error)
            return false
        }
    }

    /// Toggles mirroring of the main display or reverts back to extended desktop.
    ///
    /// Not called automatically. Mirroring broadcasts the entire main display to iPad, so user choice is required.
    public func toggleMirroring(_ enable: Bool) {
        guard let sidecar = sidecarDisplay else {
            failure = .noSidecarDisplay
            return
        }
        guard let main = mainDisplay else {
            failure = .noMainDisplay
            return
        }

        // When reverting to extension, if a canvas exists, iPad is restored to mirroring that canvas.
        // Simply unmirroring drops iPad to default resolution and loses canvas-defined dimensions.
        let canvas = managedDisplays?.managedDisplayID
            .flatMap { id in displays.first(where: { $0.id == id }) }

        // macOS repositions displays every time mirroring is toggled. Save previous position
        // before transition so it can be restored when reverting to extended desktop.
        if enable, let target = arrangementTarget {
            pendingArrangement = DisplayAnchor.from(mainBounds: main.bounds, targetBounds: target.bounds)
        }

        // Mirroring reverts upon logout. Permanent persistence causes macOS to remember mirroring
        // settings so iPad reconnects mirrored; mirroring is a session choice, not device-persisted setting.
        let result = configurator.configureMirroring(
            displayID: sidecar.id,
            mirrorOf: enable ? main.id : canvas?.id,
            persistence: .session
        )

        switch result {
        case .success:
            self.isSidecarMirrored = enable
            self.failure = nil
            // Restores position immediately upon returning to extension. Waiting introduces a brief flicker
            // of macOS default placement. CoreGraphics applies changes immediately upon commit (0ms observed incorrect placement).
            //
            // Since display list is not yet updated, arrangementTarget cannot be trusted.
            // Pin target directly to the canvas located above.
            if !enable, let canvas, let anchor = pendingArrangement {
                pendingArrangement = nil
                applyArrangement(anchor, to: canvas)
            }

            // Toggling mirroring rebuilds the entire display configuration.
            refreshAfterModeChange()

        case .failure(let error):
            self.record(error)
        }
    }

    /// Initiates connection to a specific Sidecar device.
    public func connectSidecar(to device: SidecarDeviceInfo) {
        self.isConnecting = true
        self.failure = nil

        sidecarConnector.connect(to: device) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isConnecting = false
                // Failure is not displayed here. SidecarCore presents its own alert with more specific details;
                // showing it here would result in duplicate messages.
                self?.failure = nil
                switch result {
                case .success:
                    self?.lastConnectFailure = nil
                    self?.lastConnectedDevice = device
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.refreshDisplays()
                    }
                case .failure:
                    self?.lastConnectFailure = device
                }
            }
        }
    }

    /// Terminates currently connected Sidecar session.
    public func disconnectSidecar() {
        self.isConnecting = true
        self.failure = nil

        sidecarConnector.disconnect { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isConnecting = false
                // Failures not displayed for the same reason as connect.
                self?.failure = nil
                if case .success = result {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.refreshDisplays()
                    }
                }
            }
        }
    }

    /// Changes resolution of the Sidecar display.
    public func changeSidecarResolution(_ mode: DisplayResolutionMode) {
        guard let sidecar = sidecarDisplay else {
            failure = .noSidecarDisplay
            return
        }

        let result = modeManager.setDisplayResolution(displayID: sidecar.id, mode: mode, persistence: .permanent)

        switch result {
        case .success:
            self.currentResolution = mode
            self.failure = nil
            refreshAfterModeChange()

        case .failure(let error):
            self.record(error)
        }
    }

    /// Changes resolution of the main display. iPad mirrors this during mirroring.
    ///
    /// Modifies the Mac primary display, so the UI must clearly indicate the main display as target.
    public func changeMainResolution(_ mode: DisplayResolutionMode) {
        guard let main = mainDisplay else {
            failure = .noMainDisplay
            return
        }

        // Reverts upon logout. Mirroring resolution is a temporary adjustment tied to Sidecar session;
        // Mac primary display settings should not be permanently overwritten by this tool.
        switch modeManager.setDisplayResolution(displayID: main.id, mode: mode, persistence: .session) {
        case .success:
            self.failure = nil
            refreshAfterModeChange()
        case .failure(let error):
            self.record(error)
        }
    }

    /// Immediately changes Sidecar display arrangement by applying a preset.
    public func applyPreset(_ preset: DisplayArrangementPreset) {
        guard let main = mainDisplay else {
            failure = .noMainDisplay
            return
        }

        guard let sidecar = arrangementTarget else {
            failure = .noSidecarDisplay
            return
        }

        let targetOrigin = calculator.calculateOrigin(
            mainBounds: main.bounds,
            targetBounds: sidecar.bounds,
            preset: preset
        )

        let result = configurator.configureDisplayOrigin(
            displayID: sidecar.id,
            origin: targetOrigin
        )

        switch result {
        case .success:
            self.lastAppliedPreset = preset
            self.presetManager.saveLastPreset(preset)
            self.failure = nil
            // Refresh state after change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshDisplays()
            }

        case .failure(let error):
            self.record(error)
        }
    }

    /// Immediately restores the last saved preset.
    public func applyLastPreset() {
        if let preset = lastAppliedPreset ?? presetManager.loadLastPreset() {
            applyPreset(preset)
        } else {
            // Default: Left Center
            applyPreset(.leftCenter)
        }
    }

    /// Immediately applies arbitrary target coordinates calculated via drag-and-drop to the system.
    public func applyCustomOrigin(_ origin: TargetDisplayOrigin) {
        guard moveArrangementTarget(to: origin) else { return }

        // Clears stored preset as well. Clearing memory alone would revive old preset on next run.
        self.lastAppliedPreset = nil
        self.presetManager.clearLastPreset()
    }

    /// Inherits previous iPad position when arrangement target switches to canvas.
    ///
    /// As a newly created display, canvas defaults to macOS-assigned placement, which would discard user arrangement.
    /// If a preset was active, recalculates using canvas dimensions, since copying raw coordinates across different display sizes misaligns preset intent.
    /// For manually dragged positions without a saved preset, raw coordinates are preserved.
    public func inheritArrangement(from anchor: DisplayAnchor) {
        guard let target = arrangementTarget else {
            failure = .noSidecarDisplay
            return
        }
        applyArrangement(anchor, to: target)
    }

    /// Position of arrangement target prior to entering mirroring. Restored upon reverting to extension.
    private var pendingArrangement: DisplayAnchor?

    /// Applies arrangement to the specified display.
    ///
    /// If a preset is saved, recalculates for the target display dimensions.
    /// If none (manually dragged), resolves anchor using target display dimensions.
    /// In neither case are raw coordinates copied directly, preventing misalignment caused by size discrepancies between canvas and iPad.
    private func applyArrangement(_ anchor: DisplayAnchor, to target: DisplayInfo) {
        guard let main = mainDisplay else { return }

        // Checks saved preset only. lastAppliedPreset reflects current match, so relying on it when about to move would keep it in place.
        // A non-nil saved preset indicates user explicitly selected a preset and hasn't dragged since.
        let wanted: TargetDisplayOrigin
        if let preset = presetManager.loadLastPreset() {
            wanted = calculator.calculateOrigin(
                mainBounds: main.bounds,
                targetBounds: target.bounds,
                preset: preset
            )
        } else {
            wanted = anchor.origin(mainBounds: main.bounds, targetBounds: target.bounds)
        }

        if case .failure(let error) = configurator.configureDisplayOrigin(displayID: target.id, origin: wanted) {
            record(error)
        }
    }

    /// Moves arrangement target to specified coordinates without modifying preset storage.
    @discardableResult
    private func moveArrangementTarget(to origin: TargetDisplayOrigin) -> Bool {
        guard let target = arrangementTarget else {
            failure = .noSidecarDisplay
            return false
        }

        switch configurator.configureDisplayOrigin(displayID: target.id, origin: origin) {
        case .success:
            self.failure = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshDisplays()
            }
            return true

        case .failure(let error):
            self.record(error)
            return false
        }
    }
}
