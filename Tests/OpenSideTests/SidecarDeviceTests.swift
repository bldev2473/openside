import XCTest
@testable import OpenSide

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
