import XCTest
@testable import OpenSideCore

/// Unit test class for Sidecar device model and manager.
final class SidecarDeviceTests: XCTestCase {

    /// Verifies SidecarDeviceInfo instantiation and equality.
    func testSidecarDeviceInfoModel() {
        let device1 = SidecarDeviceInfo(id: "UUID-123", name: "User's iPad", isConnected: false)
        let device2 = SidecarDeviceInfo(id: "UUID-123", name: "User's iPad", isConnected: false)
        let device3 = SidecarDeviceInfo(id: "UUID-456", name: "Other iPad", isConnected: true)

        XCTAssertEqual(device1, device2)
        XCTAssertNotEqual(device1, device3)
        XCTAssertFalse(device1.isConnected)
        XCTAssertTrue(device3.isConnected)
    }

    /// Verifies SidecarDeviceManager initialization and safety.
    func testSidecarDeviceManagerInitialization() {
        let manager = SidecarDeviceManager()
        let devices = manager.getAvailableDevices()
        // Must safely return devices or empty array without throwing exceptions
        XCTAssertTrue(devices.count >= 0)
    }
}

final class SidecarReadinessTests: XCTestCase {

    struct StubChecker: SidecarReadinessChecking {
        let issues: [SidecarReadinessIssue]
        func currentIssues() -> [SidecarReadinessIssue] { issues }
    }

    /// Forces a state with no Sidecar display attached to avoid dependency on actual system state.
    struct StubDetector: DisplayDetecting {
        func getActiveDisplays() -> [DisplayInfo] { [] }
        func getSidecarDisplay() -> DisplayInfo? { nil }
        func getMainDisplay() -> DisplayInfo? { nil }
    }

    struct StubConnector: SidecarConnecting {
        let devices: [SidecarDeviceInfo]
        func currentSessionInfo() -> SidecarSessionInfo? { nil }
        func getAvailableDevices() -> [SidecarDeviceInfo] { devices }
        func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
        func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
    }

    @MainActor
    func testIssuesSurfaceEvenWhenDeviceIsListed() {
        let withoutDevice = DisplayManagerViewModel(
            detector: StubDetector(),
            sidecarConnector: StubConnector(devices: []),
            readinessChecker: StubChecker(issues: [.wifiOff])
        )
        XCTAssertEqual(withoutDevice.readinessIssues, [.wifiOff])

        // Must report issues because connection will fail if prerequisites are broken even if devices remain listed
        let withDevice = DisplayManagerViewModel(
            detector: StubDetector(),
            sidecarConnector: StubConnector(devices: [
                SidecarDeviceInfo(id: "1", name: "iPad", isConnected: false)
            ]),
            readinessChecker: StubChecker(issues: [.wifiOff])
        )
        XCTAssertEqual(withDevice.readinessIssues, [.wifiOff])
    }
}

final class SidecarReadinessSettingsURLTests: XCTestCase {

    /// Passing nonexistent bundle IDs still opens System Settings without error, hiding mistakes at runtime.
    /// Verifies that URLs point to extensions actually installed on the system.
    func testSettingsURLsPointAtInstalledExtensions() throws {
        let extensionsDir = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")
        guard let bundles = try? FileManager.default.contentsOfDirectory(
            at: extensionsDir, includingPropertiesForKeys: nil
        ) else {
            throw XCTSkip("System Settings extension directory does not exist in this environment")
        }

        let installedIDs = Set(bundles.compactMap { url -> String? in
            Bundle(url: url)?.bundleIdentifier
        })
        XCTAssertFalse(installedIDs.isEmpty, "Failed to read any installed extensions")

        for issue in SidecarReadinessIssue.allCases {
            let url = try XCTUnwrap(issue.settingsURL, "Missing settings URL for \(issue)")
            let identifier = url.absoluteString
                .replacingOccurrences(of: "x-apple.systempreferences:", with: "")
            XCTAssertTrue(
                installedIDs.contains(identifier),
                "Settings pane ID does not exist for \(issue): \(identifier)"
            )
        }
    }
}

final class CustomArrangementPersistenceTests: XCTestCase {

    final class SpyPresetManager: PresetManaging, @unchecked Sendable {
        var stored: DisplayArrangementPreset?
        func saveLastPreset(_ preset: DisplayArrangementPreset) { stored = preset }
        func loadLastPreset() -> DisplayArrangementPreset? { stored }
        func clearLastPreset() { stored = nil }
    }

    final class StubDetector: DisplayDetecting, @unchecked Sendable {
        let sidecar = DisplayInfo(
            id: 1, uuid: "TEST-SIDECAR", name: "Sidecar Display (AirPlay)",
            bounds: CGRect(x: 0, y: 0, width: 1112, height: 834),
            isMain: false, isBuiltin: false, isSidecar: true
        )
        let main = DisplayInfo(
            id: 99, uuid: "TEST-MAIN", name: "Built-in",
            bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            isMain: true, isBuiltin: true, isSidecar: false
        )
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    struct NoopConfigurator: DisplayConfiguring {
        func configureDisplayOrigin(
            displayID: CGDirectDisplayID,
            origin: TargetDisplayOrigin
        ) -> Result<Void, DisplayConfigurationError> { .success(()) }
        func configureMirroring(
            displayID: CGDirectDisplayID,
            mirrorOf masterID: CGDirectDisplayID?,
            persistence: DisplayConfigurationPersistence
        ) -> Result<Void, DisplayConfigurationError> { .success(()) }
        func isMirroring(displayID: CGDirectDisplayID) -> Bool { false }
    }

    /// If dragged manually after applying a preset, the stored preset must also be cleared.
    /// Clearing memory alone would revive the supposedly-cleared preset as active on next launch.
    @MainActor
    func testDraggingClearsTheStoredPreset() {
        let presets = SpyPresetManager()
        let viewModel = DisplayManagerViewModel(
            detector: StubDetector(),
            configurator: NoopConfigurator(),
            presetManager: presets
        )

        viewModel.applyPreset(.rightCenter)
        XCTAssertEqual(presets.stored, .rightCenter)

        viewModel.applyCustomOrigin(TargetDisplayOrigin(x: 100, y: 200))
        XCTAssertNil(viewModel.lastAppliedPreset, "Selection highlight must disappear from UI")
        XCTAssertNil(presets.stored, "Leaving in storage revives preset on next launch")

        // Simulates app restart.
        let restarted = DisplayManagerViewModel(
            detector: StubDetector(),
            configurator: NoopConfigurator(),
            presetManager: presets
        )
        XCTAssertNil(restarted.lastAppliedPreset)
    }
}

final class UserDefaultsPresetManagerTests: XCTestCase {

    /// Verifies that the real storage implementation actually clears values rather than a mock.
    func testClearRemovesTheStoredValue() throws {
        // Generating random names leaves abandoned plist files on every run.
        // Use a consistent name and clean up values and file upon teardown.
        let suiteName = TestDefaults.name("PresetStore")
        let defaults = try TestDefaults.open(suiteName)
        defer { TestDefaults.remove(suiteName) }

        let manager = UserDefaultsPresetManager(userDefaults: defaults)

        manager.saveLastPreset(.rightCenter)
        XCTAssertEqual(manager.loadLastPreset(), .rightCenter)

        manager.clearLastPreset()
        XCTAssertNil(manager.loadLastPreset(), "Must be physically removed from storage")

        // Must remain absent when opening the same suite anew (corresponds to app restart).
        let reopened = UserDefaultsPresetManager(userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)))
        XCTAssertNil(reopened.loadLastPreset())
    }
}

final class DeviceListRefreshTests: XCTestCase {

    final class CountingConnector: SidecarConnecting, @unchecked Sendable {
        var devices: [SidecarDeviceInfo] = []
        var listCalls = 0
        func currentSessionInfo() -> SidecarSessionInfo? { nil }
        func getAvailableDevices() -> [SidecarDeviceInfo] {
            listCalls += 1
            return devices
        }
        func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
        func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
    }

    final class CountingDetector: DisplayDetecting, @unchecked Sendable {
        var displayCalls = 0
        func getActiveDisplays() -> [DisplayInfo] { displayCalls += 1; return [] }
        func getSidecarDisplay() -> DisplayInfo? { nil }
        func getMainDisplay() -> DisplayInfo? { nil }
    }

    /// Frequently invoked background path. Must only query device list without touching displays.
    @MainActor
    func testRefreshingDevicesDoesNotTouchDisplays() {
        let connector = CountingConnector()
        let detector = CountingDetector()
        let viewModel = DisplayManagerViewModel(detector: detector, sidecarConnector: connector)

        let displayCallsAfterInit = detector.displayCalls
        let device = SidecarDeviceInfo(id: "A", name: "iPad", isConnected: false)
        connector.devices = [device]

        viewModel.refreshSidecarDevices()

        XCTAssertEqual(viewModel.availableSidecarDevices, [device])
        XCTAssertEqual(detector.displayCalls, displayCallsAfterInit, "Displays must not be re-enumerated")
    }
}

final class ConnectFailureTests: XCTestCase {

    struct StubDetector: DisplayDetecting {
        func getActiveDisplays() -> [DisplayInfo] { [] }
        func getSidecarDisplay() -> DisplayInfo? { nil }
        func getMainDisplay() -> DisplayInfo? { nil }
    }

    struct StubChecker: SidecarReadinessChecking {
        func currentIssues() -> [SidecarReadinessIssue] { [] }
    }

    final class ScriptedConnector: SidecarConnecting, @unchecked Sendable {
        var fails = false
        func currentSessionInfo() -> SidecarSessionInfo? { nil }
        func getAvailableDevices() -> [SidecarDeviceInfo] { [] }
        func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
            completion(fails ? .failure(NSError(domain: "Test", code: 1)) : .success(()))
        }
        func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
            completion(.success(()))
        }
    }

    private static let device = SidecarDeviceInfo(id: "A", name: "iPad", isConnected: false)

    /// Connection failure is not shown on screen but also not discarded.
    /// Auto-connect inspects this flag to avoid repeatedly connecting to the same failing device.
    @MainActor
    func testFailureIsRecordedAndClearedOnSuccess() async {
        let connector = ScriptedConnector()
        let viewModel = DisplayManagerViewModel(
            detector: StubDetector(),
            sidecarConnector: connector,
            readinessChecker: StubChecker()
        )
        XCTAssertNil(viewModel.lastConnectFailure)

        connector.fails = true
        viewModel.connectSidecar(to: Self.device)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.lastConnectFailure, Self.device)
        XCTAssertNil(viewModel.failure, "macOS presents its own alert, so we do not show one")

        connector.fails = false
        viewModel.connectSidecar(to: Self.device)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(viewModel.lastConnectFailure, "Clears flag upon success")
    }

    /// Auto-connect learns which device to connect to from this; must not learn failing devices.
    @MainActor
    func testOnlyASuccessfulConnectionIsRemembered() async {
        let connector = ScriptedConnector()
        let viewModel = DisplayManagerViewModel(
            detector: StubDetector(),
            sidecarConnector: connector,
            readinessChecker: StubChecker()
        )
        XCTAssertNil(viewModel.lastConnectedDevice)

        connector.fails = true
        viewModel.connectSidecar(to: Self.device)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(viewModel.lastConnectedDevice, "Failed devices must not be remembered")

        connector.fails = false
        viewModel.connectSidecar(to: Self.device)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.lastConnectedDevice, Self.device)
    }
}

final class ManagedDisplayTests: XCTestCase {

    final class StubManaged: ManagedDisplayReporting, @unchecked Sendable {
        var managedDisplayID: CGDirectDisplayID?
        init(_ id: CGDirectDisplayID?) { managedDisplayID = id }
    }

    final class TwoDisplayDetector: DisplayDetecting, @unchecked Sendable {
        let main = DisplayInfo(id: 1, uuid: "M", name: "Built-in",
                               bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                               isMain: true, isBuiltin: true, isSidecar: false)
        /// iPad mirroring the canvas, matching canvas dimensions.
        let sidecar = DisplayInfo(id: 2, uuid: "S", name: "Sidecar Display (AirPlay)",
                                  bounds: CGRect(x: 0, y: 0, width: 834, height: 1112),
                                  isMain: false, isBuiltin: false, isSidecar: true, mirrorSourceID: 3)
        /// App-created virtual canvas.
        let canvas = DisplayInfo(id: 3, uuid: "C", name: "OpenSide Canvas",
                                 bounds: CGRect(x: 1512, y: 0, width: 834, height: 1112),
                                 isMain: false, isBuiltin: false, isSidecar: false)
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar, canvas] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    final class RecordingConfigurator: DisplayConfiguring, @unchecked Sendable {
        var movedIDs: [CGDirectDisplayID] = []
        /// Received target origins to move to.
        var movedOrigins: [TargetDisplayOrigin] = []
        /// Received master display IDs for mirroring; nil indicates unmirroring.
        var mirrorRequests: [CGDirectDisplayID?] = []
        func configureDisplayOrigin(displayID: CGDirectDisplayID, origin: TargetDisplayOrigin) -> Result<Void, DisplayConfigurationError> {
            movedIDs.append(displayID); movedOrigins.append(origin); return .success(())
        }
        func configureMirroring(displayID: CGDirectDisplayID, mirrorOf masterID: CGDirectDisplayID?, persistence: DisplayConfigurationPersistence) -> Result<Void, DisplayConfigurationError> {
            mirrorRequests.append(masterID); return .success(())
        }
        func isMirroring(displayID: CGDirectDisplayID) -> Bool { false }
    }

    struct QuietChecker: SidecarReadinessChecking {
        func currentIssues() -> [SidecarReadinessIssue] { [] }
    }

    /// While using a canvas, desktop extension occurs on the canvas.
    /// Moving the iPad has no effect.
    @MainActor
    func testPresetMovesTheCanvasWhenOneIsInUse() {
        let configurator = RecordingConfigurator()
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: configurator,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        viewModel.applyPreset(.rightCenter)
        XCTAssertEqual(configurator.movedIDs, [3], "Must move the canvas (3)")
    }

    /// Moves iPad as usual when no canvas exists.
    @MainActor
    func testPresetMovesTheSidecarWithoutACanvas() {
        let configurator = RecordingConfigurator()
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: configurator,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(nil)
        )
        viewModel.applyPreset(.rightCenter)
        XCTAssertEqual(configurator.movedIDs, [2], "Must move iPad (2)")
    }

    /// Canvas exists, but user reverted to extension so iPad mirrors nothing.
    final class UnmirroredCanvasDetector: DisplayDetecting, @unchecked Sendable {
        let main = DisplayInfo(id: 1, uuid: "M", name: "Built-in",
                               bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                               isMain: true, isBuiltin: true, isSidecar: false)
        let sidecar = DisplayInfo(id: 2, uuid: "S", name: "Sidecar Display (AirPlay)",
                                  bounds: CGRect(x: -1112, y: 0, width: 1112, height: 834),
                                  isMain: false, isBuiltin: false, isSidecar: true)
        let canvas = DisplayInfo(id: 3, uuid: "C", name: "OpenSide Canvas",
                                 bounds: CGRect(x: 1512, y: 0, width: 1112, height: 834),
                                 isMain: false, isBuiltin: false, isSidecar: false)
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar, canvas] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    /// iPad mirroring a canvas appears as desktop extension to the user. The desktop extends to the canvas
    /// and iPad displays a replica. Treating it as mirroring would hide arrangement and resolution controls.
    @MainActor
    func testShowingTheCanvasDoesNotCountAsMirroring() {
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: RecordingConfigurator(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertFalse(viewModel.isSidecarMirrored, "Mirroring a canvas counts as desktop extension")
    }

    /// When user reverts to extension, iPad is unlinked from canvas; iPad becomes the arrangement target.
    @MainActor
    func testPresetMovesTheSidecarOnceItStopsShowingTheCanvas() {
        let configurator = RecordingConfigurator()
        let viewModel = DisplayManagerViewModel(
            detector: UnmirroredCanvasDetector(),
            configurator: configurator,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        viewModel.applyPreset(.rightCenter)
        XCTAssertEqual(configurator.movedIDs, [2], "Must move iPad (2) once mirroring is disabled")
    }

    /// State where iPad is mirroring main display (1).
    final class MainMirrorDetector: DisplayDetecting, @unchecked Sendable {
        let main = DisplayInfo(id: 1, uuid: "M", name: "Built-in",
                               bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                               isMain: true, isBuiltin: true, isSidecar: false)
        let sidecar = DisplayInfo(id: 2, uuid: "S", name: "Sidecar Display (AirPlay)",
                                  bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                  isMain: false, isBuiltin: false, isSidecar: true, mirrorSourceID: 1)
        let canvas = DisplayInfo(id: 3, uuid: "C", name: "OpenSide Canvas",
                                 bounds: CGRect(x: 1512, y: 0, width: 1112, height: 834),
                                 isMain: false, isBuiltin: false, isSidecar: false)
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar, canvas] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    /// Even if a canvas exists, iPad mirroring the main screen counts as mirroring.
    @MainActor
    func testMirroringTheMainScreenStillCountsAsMirroring() {
        let viewModel = DisplayManagerViewModel(
            detector: MainMirrorDetector(),
            configurator: RecordingConfigurator(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertTrue(viewModel.isSidecarMirrored, "Mirroring main screen counts as mirroring")
        XCTAssertFalse(viewModel.isShowingCanvas, "Mirrored target is not canvas")
    }

    /// Rationale for resolution control. Canvas determines resolution while mirroring it.
    @MainActor
    func testShowingCanvasIsReportedWhileTheSidecarMirrorsIt() {
        let showing = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: RecordingConfigurator(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertTrue(showing.isShowingCanvas)

        let notShowing = DisplayManagerViewModel(
            detector: UnmirroredCanvasDetector(),
            configurator: RecordingConfigurator(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertFalse(notShowing.isShowingCanvas, "Disabling mirroring means canvas is not mirrored")
    }

    /// When toggling mirroring back to extension while using a canvas, iPad must return to mirroring the canvas.
    /// Simply unmirroring drops iPad to default resolution and loses custom dimensions.
    @MainActor
    func testReturningToExtendSendsTheSidecarBackToTheCanvas() {
        let configurator = RecordingConfigurator()
        let viewModel = DisplayManagerViewModel(
            detector: MainMirrorDetector(),
            configurator: configurator,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        viewModel.toggleMirroring(false)
        XCTAssertEqual(configurator.mirrorRequests, [3], "Must remirror canvas (3) when returning to extension")
    }

    /// Extension is simply unmirroring when no canvas exists.
    @MainActor
    func testReturningToExtendWithoutACanvasJustUnmirrors() {
        let configurator = RecordingConfigurator()
        let viewModel = DisplayManagerViewModel(
            detector: MainMirrorDetector(),
            configurator: configurator,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(nil)
        )
        viewModel.toggleMirroring(false)
        XCTAssertEqual(configurator.mirrorRequests, [nil], "Simply unmirrors when no canvas exists")
    }

    /// Manually dragged positions have no saved preset; resolves anchor using canvas dimensions.
    @MainActor
    func testCanvasInheritsAHandPlacedSpot() {
        let configurator = RecordingConfigurator()
        let presets = CustomArrangementPersistenceTests.SpyPresetManager()
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: configurator,
            presetManager: presets,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        // Position formerly placed at middle of left edge.
        viewModel.inheritArrangement(from: DisplayAnchor(edge: .left, ratio: 0.5))

        XCTAssertEqual(configurator.movedIDs, [3], "Must move canvas (3)")
        // Canvas is 834x1112; must attach to left edge and align center to half the main screen height.
        XCTAssertEqual(configurator.movedOrigins.first?.x, -834)
        XCTAssertEqual(Double(configurator.movedOrigins.first?.y ?? 0) + 1112 / 2, 982 * 0.5, accuracy: 1)
    }

    /// If a preset is saved, recalculates for canvas dimensions.
    /// Discrepancy between iPad and canvas dimensions causes raw coordinates to misalign preset intent.
    @MainActor
    func testCanvasInheritsTheStoredPresetRatherThanRawCoordinates() {
        let configurator = RecordingConfigurator()
        let presets = CustomArrangementPersistenceTests.SpyPresetManager()
        presets.stored = .rightCenter
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: configurator,
            presetManager: presets,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        viewModel.inheritArrangement(from: DisplayAnchor(edge: .left, ratio: 0.5))

        XCTAssertEqual(configurator.movedIDs, [3], "Must move canvas (3)")
        XCTAssertEqual(configurator.movedOrigins.first?.x, 1512,
                       "Must follow preset if right even if anchor was left")
        XCTAssertEqual(presets.stored, .rightCenter, "Inheritance must not clear stored preset")
    }

    /// Simulates screen state transitions; macOS repositions displays every time mirroring is toggled.
    final class MutableCanvasDetector: DisplayDetecting, @unchecked Sendable {
        var canvasOrigin = CGPoint(x: -2000, y: 120)
        /// What iPad mirrors: 3 for canvas, 1 for main.
        var sidecarMirrorSource: CGDirectDisplayID? = 3

        var main: DisplayInfo {
            DisplayInfo(id: 1, uuid: "M", name: "Built-in",
                        bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                        isMain: true, isBuiltin: true, isSidecar: false)
        }
        var sidecar: DisplayInfo {
            DisplayInfo(id: 2, uuid: "S", name: "Sidecar Display (AirPlay)",
                        bounds: CGRect(x: 0, y: 0, width: 1112, height: 834),
                        isMain: false, isBuiltin: false, isSidecar: true,
                        mirrorSourceID: sidecarMirrorSource)
        }
        var canvas: DisplayInfo {
            DisplayInfo(id: 3, uuid: "C", name: "OpenSide Canvas",
                        bounds: CGRect(x: canvasOrigin.x, y: canvasOrigin.y, width: 1112, height: 834),
                        isMain: false, isBuiltin: false, isSidecar: false)
        }
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar, canvas] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    /// When returning to extension after manually placing canvas and entering mirroring, it must return to that spot.
    /// macOS repositions displays every time mirroring toggles, so our code must remember and restore it.
    @MainActor
    func testArrangementSurvivesAMirroringRoundTrip() {
        let configurator = RecordingConfigurator()
        let detector = MutableCanvasDetector()
        // Stored preset is nil, indicating a manually dragged position.
        let presets = CustomArrangementPersistenceTests.SpyPresetManager()
        let viewModel = DisplayManagerViewModel(
            detector: detector,
            configurator: configurator,
            presetManager: presets,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertTrue(viewModel.isShowingCanvas, "Must initially mirror canvas")

        viewModel.toggleMirroring(true)

        // macOS moved canvas to another origin upon enabling mirroring.
        detector.sidecarMirrorSource = 1
        detector.canvasOrigin = .zero
        viewModel.refreshDisplays()

        // Restoration must complete within this call. Waiting introduces a brief flicker
        // of misplaced positioning on iPad (CoreGraphics reflects commits immediately).
        viewModel.toggleMirroring(false)

        XCTAssertEqual(configurator.movedIDs, [3], "Must restore canvas (3)")
        XCTAssertEqual(configurator.movedOrigins.first?.x, -1112,
                       "Must attach to left of main screen as before mirroring")
    }

    /// Positioning must be applied simultaneously when configuring canvas mirroring.
    /// Configuring first and moving later briefly exposes macOS's default position on iPad.
    @MainActor
    func testMirroringOntoACanvasPlacesItAtOnce() {
        let configurator = RecordingConfigurator()
        let detector = MutableCanvasDetector()
        detector.sidecarMirrorSource = nil  // Not mirroring anything yet
        let viewModel = DisplayManagerViewModel(
            detector: detector,
            configurator: configurator,
            presetManager: CustomArrangementPersistenceTests.SpyPresetManager(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )

        _ = viewModel.mirrorSidecar(onto: 3, placing: DisplayAnchor(edge: .right, ratio: 0.5))

        XCTAssertEqual(configurator.mirrorRequests, [3])
        XCTAssertEqual(configurator.movedIDs, [3], "Must position canvas immediately upon establishing mirroring")
        XCTAssertEqual(configurator.movedOrigins.first?.x, 1512, "Must attach to right of main screen")
    }
}
