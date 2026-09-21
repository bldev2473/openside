import XCTest
import CoreGraphics
@testable import OpenSideCore

/// 어떤 화면을 사이드카로 볼지 가리는 규칙.
///
/// 복제 중에는 NSScreen 이 그 화면을 내놓지 않아 이름을 못 읽는다. 그래서 이름을 못 읽는
/// 복제 화면을 사이드카로 보고 있었는데, 그러면 HDMI 로 붙인 모니터를 복제로 쓸 때 그
/// 모니터가 iPad 로 잡힌다.
final class SidecarDisplayIdentificationTests: XCTestCase {

    /// 세션을 몇 번 물었는지 센다.
    private final class SessionSpy: SidecarConnecting, @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var asked: Int { lock.withLock { count } }

        func currentSessionInfo() -> SidecarSessionInfo? {
            lock.withLock { count += 1 }
            return nil
        }
        func getAvailableDevices() -> [SidecarDeviceInfo] { [] }
        func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
        func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
    }

    /// 이름에 iPad 가 들어가면 세션을 묻지 않는다. 확장 중에는 이름을 읽을 수 있다.
    func testANamedSidecarScreenIsRecognisedWithoutASession() {
        XCTAssertTrue(SidecarDisplayRule.isSidecar(
            name: "iPad", isBuiltin: false, isOurs: false,
            isMirrored: false, hasSidecarSession: false
        ))
    }

    /// 세션이 붙어 있는 동안 이름 없는 복제 화면은 사이드카로 본다. 예전 동작이다.
    func testAnUnnamedMirroredScreenIsSidecarWhileASessionRuns() {
        XCTAssertTrue(SidecarDisplayRule.isSidecar(
            name: "External Display 9", isBuiltin: false, isOurs: false,
            isMirrored: true, hasSidecarSession: true
        ))
    }

    /// iPad 가 붙어 있지 않은데 외장 모니터를 복제로 쓰면, 그것은 사이드카가 아니다.
    ///
    /// 고치기 전에는 여기서 참이 나왔다. 프로젝터나 HDMI 모니터를 복제로 두면 그 화면이
    /// iPad 로 잡혀, 해상도 행과 정렬이 엉뚱한 화면을 겨눴다.
    func testAMirroredMonitorIsNotSidecarWhenNoSessionExists() {
        XCTAssertFalse(SidecarDisplayRule.isSidecar(
            name: "DELL U2720Q", isBuiltin: false, isOurs: false,
            isMirrored: true, hasSidecarSession: false
        ))
    }

    /// 내장 화면은 어떤 경우에도 사이드카가 아니다.
    func testTheBuiltInScreenIsNeverSidecar() {
        for mirrored in [true, false] {
            for session in [true, false] {
                XCTAssertFalse(SidecarDisplayRule.isSidecar(
                    name: "iPad", isBuiltin: true, isOurs: false,
                    isMirrored: mirrored, hasSidecarSession: session
                ))
            }
        }
    }

    /// 이 앱이 만든 화면은 사이드카가 아니다. 그것도 비내장이고 이름이 없다.
    func testOurOwnScreenIsNeverSidecar() {
        XCTAssertFalse(SidecarDisplayRule.isSidecar(
            name: "External Display 9", isBuiltin: false, isOurs: true,
            isMirrored: true, hasSidecarSession: true
        ))
    }

    /// 탐지기가 세션을 실제로 물어야 한다.
    ///
    /// 규칙을 따로 시험하는 것만으로는 탐지기가 그 규칙에 무엇을 넣는지 아무도 보지 않는다.
    /// 세션을 묻지 않고 아무 값이나 넘겨도 규칙 쪽 시험은 그대로 통과한다.
    func testTheDetectorAsksWhetherASessionIsRunning() {
        let spy = SessionSpy()
        _ = CoreGraphicsDisplayDetector(sidecar: spy).getActiveDisplays()
        XCTAssertEqual(spy.asked, 1, "세션을 묻지 않았거나 화면마다 되물었다")
    }

    /// 목록을 도는 동안 한 번만 묻는다. 화면마다 물으면 도중에 값이 바뀌었을 때 같은
    /// 목록 안에서 화면마다 다른 판정이 나온다.
    func testTheSessionIsReadOncePerRefresh() {
        let spy = SessionSpy()
        let detector = CoreGraphicsDisplayDetector(sidecar: spy)
        _ = detector.getActiveDisplays()
        _ = detector.getActiveDisplays()
        XCTAssertEqual(spy.asked, 2)
    }

    /// AirPlay 와 Sidecar 라는 이름도 알아본다. macOS 가 둘 다 쓴다.
    func testTheOtherNamesMacOSUsesAreRecognised() {
        for name in ["Sidecar Display (AirPlay)", "AirPlay Display", "iPad Pro"] {
            XCTAssertTrue(SidecarDisplayRule.isSidecar(
                name: name, isBuiltin: false, isOurs: false,
                isMirrored: false, hasSidecarSession: false
            ), "\(name) 을 못 알아봤다")
        }
    }
}
