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
