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

        // Wait for MainActor propagation
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

    /// When the iPad can no longer be read, both badge and estimate must be cleared.
    /// Leaving the last successful value causes users to mistake it for the current level.
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
        XCTAssertNil(viewModel.sidecarBattery, "Badge must disappear when device is lost")
        XCTAssertNil(viewModel.remainingEstimate, "Estimate is meaningless if device cannot be read")
    }
}
