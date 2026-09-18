import XCTest
@testable import OpenSideCore

/// 사이드카 디바이스 모델 및 관리자 단위 테스트 클래스
final class SidecarDeviceTests: XCTestCase {

    /// SidecarDeviceInfo 모델 인스턴스화 및 동등성 검증
    func testSidecarDeviceInfoModel() {
        let device1 = SidecarDeviceInfo(id: "UUID-123", name: "홍길동의 iPad", isConnected: false)
        let device2 = SidecarDeviceInfo(id: "UUID-123", name: "홍길동의 iPad", isConnected: false)
        let device3 = SidecarDeviceInfo(id: "UUID-456", name: "다른 iPad", isConnected: true)

        XCTAssertEqual(device1, device2)
        XCTAssertNotEqual(device1, device3)
        XCTAssertFalse(device1.isConnected)
        XCTAssertTrue(device3.isConnected)
    }

    /// SidecarDeviceManager 초기화 및 안전성 검증
    func testSidecarDeviceManagerInitialization() {
        let manager = SidecarDeviceManager()
        let devices = manager.getAvailableDevices()
        // 기기가 탐색되거나 빈 배열이어도 예외 없이 안전하게 반환되어야 함
        XCTAssertTrue(devices.count >= 0)
    }
}

final class SidecarReadinessTests: XCTestCase {

    struct StubChecker: SidecarReadinessChecking {
        let issues: [SidecarReadinessIssue]
        func currentIssues() -> [SidecarReadinessIssue] { issues }
    }

    /// 사이드카 디스플레이가 붙어 있지 않은 상태를 강제합니다. 실제 시스템 상태에 의존하지 않도록.
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

        // 목록에 기기가 남아 있어도 전제 조건이 깨졌으면 연결은 실패하므로 알려야 한다
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

    /// 존재하지 않는 번들 ID 를 넘겨도 설정 앱은 오류 없이 열리므로, 값이 틀려도 실행 중에는
    /// 드러나지 않는다. 시스템에 실제로 설치된 확장인지 여기서 검증한다.
    func testSettingsURLsPointAtInstalledExtensions() throws {
        let extensionsDir = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")
        guard let bundles = try? FileManager.default.contentsOfDirectory(
            at: extensionsDir, includingPropertiesForKeys: nil
        ) else {
            throw XCTSkip("이 환경에는 System Settings 확장 디렉터리가 없다")
        }

        let installedIDs = Set(bundles.compactMap { url -> String? in
            Bundle(url: url)?.bundleIdentifier
        })
        XCTAssertFalse(installedIDs.isEmpty, "설치된 확장을 하나도 읽지 못했다")

        for issue in SidecarReadinessIssue.allCases {
            let url = try XCTUnwrap(issue.settingsURL, "\(issue) 에 설정 URL 이 없다")
            let identifier = url.absoluteString
                .replacingOccurrences(of: "x-apple.systempreferences:", with: "")
            XCTAssertTrue(
                installedIDs.contains(identifier),
                "\(issue) 의 설정 화면 ID 가 실재하지 않는다: \(identifier)"
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

    /// 프리셋을 적용한 뒤 직접 끌어다 놓으면, 저장된 프리셋도 지워져야 한다.
    /// 메모리만 지우면 앱을 다시 켰을 때 지운 줄 알았던 프리셋이 선택된 채로 살아난다.
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
        XCTAssertNil(viewModel.lastAppliedPreset, "화면에서 선택 표시가 사라져야 한다")
        XCTAssertNil(presets.stored, "저장소에도 남으면 다음 실행에서 되살아난다")

        // 다시 켠 상황을 흉내 낸다.
        let restarted = DisplayManagerViewModel(
            detector: StubDetector(),
            configurator: NoopConfigurator(),
            presetManager: presets
        )
        XCTAssertNil(restarted.lastAppliedPreset)
    }
}

final class UserDefaultsPresetManagerTests: XCTestCase {

    /// 대역이 아니라 실제 저장소 구현이 지우는지 확인한다.
    func testClearRemovesTheStoredValue() throws {
        let suiteName = "OpenSideTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = UserDefaultsPresetManager(userDefaults: defaults)

        manager.saveLastPreset(.rightCenter)
        XCTAssertEqual(manager.loadLastPreset(), .rightCenter)

        manager.clearLastPreset()
        XCTAssertNil(manager.loadLastPreset(), "저장소에서 실제로 없어져야 한다")

        // 같은 저장소를 새로 열어도 없어야 한다. 앱 재시작에 해당한다.
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

    /// 배경에서 자주 부르는 경로다. 기기 목록만 읽고 화면은 건드리지 않아야 한다.
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
        XCTAssertEqual(detector.displayCalls, displayCallsAfterInit, "화면 열거를 다시 하지 않는다")
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

    /// 연결 실패는 화면에 안 쓰지만 버리지도 않는다. 자동 연결이 이 표시를 보고
    /// 같은 기기에 되풀이해서 붙지 않는다.
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
        XCTAssertNil(viewModel.errorMessage, "macOS 가 자체 알림창을 띄우므로 우리는 안 띄운다")

        connector.fails = false
        viewModel.connectSidecar(to: Self.device)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(viewModel.lastConnectFailure, "성공하면 표시를 지운다")
    }

    /// 자동 연결은 어느 기기에 붙을지를 여기서 배운다. 실패한 기기를 배우면 안 된다.
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
        XCTAssertNil(viewModel.lastConnectedDevice, "붙지 못한 기기는 기억하지 않는다")

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
        /// iPad. 캔버스를 복제하는 중이라 크기가 캔버스와 같다.
        let sidecar = DisplayInfo(id: 2, uuid: "S", name: "Sidecar Display (AirPlay)",
                                  bounds: CGRect(x: 0, y: 0, width: 834, height: 1112),
                                  isMain: false, isBuiltin: false, isSidecar: true, mirrorSourceID: 3)
        /// 우리가 만든 캔버스.
        let canvas = DisplayInfo(id: 3, uuid: "C", name: "OpenSide Canvas",
                                 bounds: CGRect(x: 1512, y: 0, width: 834, height: 1112),
                                 isMain: false, isBuiltin: false, isSidecar: false)
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar, canvas] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    final class RecordingConfigurator: DisplayConfiguring, @unchecked Sendable {
        var movedIDs: [CGDirectDisplayID] = []
        /// 옮겨 달라고 받은 좌표들.
        var movedOrigins: [TargetDisplayOrigin] = []
        /// 복제를 걸어 달라고 받은 원본들. nil 은 복제 해제다.
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

    /// 캔버스를 쓰는 동안에는 데스크탑이 확장되는 곳이 캔버스다.
    /// iPad 를 옮기면 아무 일도 일어나지 않는다.
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
        XCTAssertEqual(configurator.movedIDs, [3], "캔버스(3)를 옮겨야 한다")
    }

    /// 캔버스가 없으면 예전처럼 iPad 를 옮긴다.
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
        XCTAssertEqual(configurator.movedIDs, [2], "iPad(2)를 옮겨야 한다")
    }

    /// 캔버스가 떠 있지만 사용자가 확장으로 되돌려 iPad 는 아무것도 복제하지 않는다.
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

    /// iPad 가 캔버스를 비추는 것은 사용자가 보기에 확장이다. 데스크탑이 캔버스로 늘어나고
    /// iPad 는 그 사본을 보여준다. 복제로 표시하면 배치와 해상도 칸이 모두 사라진다.
    @MainActor
    func testShowingTheCanvasDoesNotCountAsMirroring() {
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: RecordingConfigurator(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertFalse(viewModel.isSidecarMirrored, "캔버스를 비추는 것은 확장이다")
    }

    /// 사용자가 확장으로 되돌리면 iPad 는 캔버스와 무관해진다. 그때 배치 대상은 iPad 다.
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
        XCTAssertEqual(configurator.movedIDs, [2], "복제를 풀었으면 iPad(2)를 옮겨야 한다")
    }

    /// iPad 가 메인 화면(1)을 비추는 상태.
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

    /// 캔버스가 떠 있어도 iPad 가 메인 화면을 비추면 그것은 복제다.
    @MainActor
    func testMirroringTheMainScreenStillCountsAsMirroring() {
        let viewModel = DisplayManagerViewModel(
            detector: MainMirrorDetector(),
            configurator: RecordingConfigurator(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertTrue(viewModel.isSidecarMirrored, "메인 화면을 비추면 복제다")
        XCTAssertFalse(viewModel.isShowingCanvas, "비추는 것은 캔버스가 아니다")
    }

    /// 해상도 칸을 가릴 근거. 캔버스를 비추는 동안 해상도는 캔버스가 정한다.
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
        XCTAssertFalse(notShowing.isShowingCanvas, "복제를 풀면 캔버스를 비추는 것이 아니다")
    }

    /// 캔버스를 쓰는 동안 복제를 켰다가 확장으로 돌아오면 iPad 를 캔버스로 되돌려야 한다.
    /// 그냥 복제만 풀면 iPad 가 자기 기본 해상도로 떨어져 설정한 크기가 사라진다.
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
        XCTAssertEqual(configurator.mirrorRequests, [3], "확장으로 돌아가면 캔버스(3)를 다시 비춰야 한다")
    }

    /// 캔버스가 없으면 확장은 그냥 복제 해제다.
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
        XCTAssertEqual(configurator.mirrorRequests, [nil], "캔버스가 없으면 복제만 푼다")
    }

    /// 손으로 끌어 둔 자리에는 저장된 프리셋이 없다. 그 좌표를 그대로 캔버스가 이어받아야 한다.
    @MainActor
    func testCanvasInheritsAHandPlacedOrigin() {
        let configurator = RecordingConfigurator()
        let presets = CustomArrangementPersistenceTests.SpyPresetManager()
        let viewModel = DisplayManagerViewModel(
            detector: TwoDisplayDetector(),
            configurator: configurator,
            presetManager: presets,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        viewModel.inheritArrangement(from: TargetDisplayOrigin(x: -1112, y: 40))
        XCTAssertEqual(configurator.movedIDs, [3], "캔버스(3)를 옮겨야 한다")
        XCTAssertEqual(configurator.movedOrigins, [TargetDisplayOrigin(x: -1112, y: 40)])
    }

    /// 프리셋이 있으면 캔버스 크기로 다시 계산한다. iPad 와 캔버스의 크기가 다르면
    /// 좌표만 옮겨서는 프리셋이 뜻하던 자리에서 어긋난다.
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
        viewModel.inheritArrangement(from: TargetDisplayOrigin(x: -1112, y: 40))
        XCTAssertEqual(configurator.movedIDs, [3], "캔버스(3)를 옮겨야 한다")
        XCTAssertNotEqual(configurator.movedOrigins, [TargetDisplayOrigin(x: -1112, y: 40)],
                          "받은 좌표가 아니라 프리셋으로 계산한 자리여야 한다")
        XCTAssertEqual(presets.stored, .rightCenter, "이어받기가 프리셋을 지우면 안 된다")
    }

    /// 화면 상태가 바뀌는 것을 흉내 낸다. macOS 는 복제를 켜고 끌 때마다 자리를 다시 잡는다.
    final class MutableCanvasDetector: DisplayDetecting, @unchecked Sendable {
        var canvasOrigin = CGPoint(x: -2000, y: 120)
        /// iPad 가 무엇을 비추는지. 3 이면 캔버스, 1 이면 메인.
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

    /// 캔버스를 손으로 끌어 놓고 복제로 갔다가 확장으로 돌아오면 그 자리로 돌아와야 한다.
    /// macOS 가 복제를 켜고 끌 때마다 화면 자리를 다시 잡으므로, 우리가 기억했다 되돌려야 한다.
    @MainActor
    func testArrangementSurvivesAMirroringRoundTrip() {
        let configurator = RecordingConfigurator()
        let detector = MutableCanvasDetector()
        // 프리셋이 비어 있다. 손으로 끌어 둔 자리라는 뜻이다.
        let presets = CustomArrangementPersistenceTests.SpyPresetManager()
        let viewModel = DisplayManagerViewModel(
            detector: detector,
            configurator: configurator,
            presetManager: presets,
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )
        XCTAssertTrue(viewModel.isShowingCanvas, "먼저 캔버스를 비추는 상태여야 한다")

        viewModel.toggleMirroring(true)

        // macOS 가 복제를 켜면서 캔버스를 다른 자리로 밀었다.
        detector.sidecarMirrorSource = 1
        detector.canvasOrigin = .zero
        viewModel.refreshDisplays()

        // 되돌리기는 이 호출 안에서 끝나야 한다. 기다렸다 옮기면 그 사이 iPad 에 엉뚱한
        // 자리가 보인다 (측정: CoreGraphics 는 커밋 즉시 반영한다).
        viewModel.toggleMirroring(false)

        XCTAssertEqual(configurator.movedIDs, [3], "캔버스(3)를 되돌려야 한다")
        XCTAssertEqual(configurator.movedOrigins, [TargetDisplayOrigin(x: -2000, y: 120)],
                       "복제로 가기 전 자리로 돌아와야 한다")
    }

    /// 캔버스에 복제를 걸면서 자리도 같이 잡아야 한다. 걸어 두고 나중에 옮기면 그 사이
    /// iPad 에 macOS 가 정한 자리가 보인다.
    @MainActor
    func testMirroringOntoACanvasPlacesItAtOnce() {
        let configurator = RecordingConfigurator()
        let detector = MutableCanvasDetector()
        detector.sidecarMirrorSource = nil  // 아직 아무것도 안 비춘다
        let viewModel = DisplayManagerViewModel(
            detector: detector,
            configurator: configurator,
            presetManager: CustomArrangementPersistenceTests.SpyPresetManager(),
            readinessChecker: QuietChecker(),
            managedDisplays: StubManaged(3)
        )

        _ = viewModel.mirrorSidecar(onto: 3, placing: TargetDisplayOrigin(x: 1512, y: 465))

        XCTAssertEqual(configurator.mirrorRequests, [3])
        XCTAssertEqual(configurator.movedIDs, [3], "복제를 건 그 자리에서 캔버스를 세워야 한다")
        XCTAssertEqual(configurator.movedOrigins, [TargetDisplayOrigin(x: 1512, y: 465)])
    }
}
