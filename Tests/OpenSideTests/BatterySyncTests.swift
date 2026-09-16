import XCTest
@testable import OpenSideCore

final class BatterySyncTests: XCTestCase {

    func testSidecarBatteryInfoModelAndClamping() {
        let batteryNormal = SidecarBatteryInfo(percentage: 85, state: .unplugged)
        XCTAssertEqual(batteryNormal.percentage, 85)
        XCTAssertEqual(batteryNormal.state, .unplugged)
        XCTAssertFalse(batteryNormal.isCharging)
        XCTAssertEqual(batteryNormal.iconName, "battery.75")

        let batteryOverClamped = SidecarBatteryInfo(percentage: 120, state: .charging)
        XCTAssertEqual(batteryOverClamped.percentage, 100)
        XCTAssertTrue(batteryOverClamped.isCharging)
        XCTAssertEqual(batteryOverClamped.iconName, "battery.100.bolt")

        let batteryUnderClamped = SidecarBatteryInfo(percentage: -15, state: .unplugged)
        XCTAssertEqual(batteryUnderClamped.percentage, 0)
        XCTAssertEqual(batteryUnderClamped.iconName, "battery.0")
    }

    func testSidecarBatteryInfoCodableSerialization() throws {
        let original = SidecarBatteryInfo(percentage: 72, state: .charging)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SidecarBatteryInfo.self, from: data)

        XCTAssertEqual(decoded.percentage, original.percentage)
        XCTAssertEqual(decoded.state, original.state)
        XCTAssertEqual(decoded.isCharging, original.isCharging)
    }

    @MainActor
    func testDisplayManagerViewModelBatteryBinding() async {
        class MockBatteryReceiver: BatteryReceiving {
            var onBatteryUpdate: ((SidecarBatteryInfo?) -> Void)?
            var isListening: Bool = false

            func startListening() {
                isListening = true
            }

            func stopListening() {
                isListening = false
            }
        }

        let mockReceiver = MockBatteryReceiver()
        let viewModel = DisplayManagerViewModel(batteryReceiver: mockReceiver)

        XCTAssertTrue(mockReceiver.isListening)
        XCTAssertNil(viewModel.sidecarBattery)

        let testBattery = SidecarBatteryInfo(percentage: 90, state: .full)
        mockReceiver.onBatteryUpdate?(testBattery)

        // MainActor 반영 대기
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.sidecarBattery?.percentage, 90)
        XCTAssertEqual(viewModel.sidecarBattery?.state, .full)
    }
}

final class BatteryLossTests: XCTestCase {

    final class ManualBatterySource: BatteryReceiving, @unchecked Sendable {
        var onBatteryUpdate: ((SidecarBatteryInfo?) -> Void)?
        func startListening() {}
        func stopListening() {}
    }

    final class ConstantEstimator: RemainingTimeEstimating, @unchecked Sendable {
        func estimatedRemaining(currentBattery: Int) -> TimeInterval? { 3600 }
    }

    /// iPad 를 더 이상 읽을 수 없으면 배지와 추정을 함께 비워야 한다.
    /// 마지막 성공값이 남으면 사용자가 그것을 현재 잔량으로 읽는다.
    @MainActor
    func testLosingTheDeviceClearsBatteryAndEstimate() async {
        let source = ManualBatterySource()
        let viewModel = DisplayManagerViewModel(
            batteryReceiver: source,
            remainingTimeEstimator: ConstantEstimator()
        )

        source.onBatteryUpdate?(SidecarBatteryInfo(percentage: 42, state: .unplugged))
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.sidecarBattery?.percentage, 42)
        XCTAssertEqual(viewModel.remainingEstimate, 3600)

        source.onBatteryUpdate?(nil)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(viewModel.sidecarBattery, "기기가 사라지면 배지도 사라져야 한다")
        XCTAssertNil(viewModel.remainingEstimate, "읽을 수 없으면 추정도 의미가 없다")
    }
}
