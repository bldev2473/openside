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
