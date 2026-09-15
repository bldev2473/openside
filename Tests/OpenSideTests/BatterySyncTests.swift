import XCTest
@testable import OpenSide

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

    final class FakeKeyValueStore: KeyValueStoring {
        private var storage: [String: Data] = [:]

        func data(forKey key: String) -> Data? {
            storage[key]
        }

        func set(_ data: Data?, forKey key: String) {
            storage[key] = data
        }

        func synchronize() -> Bool { true }
    }

    func testCloudBatteryReceiverDecodesStoredValue() throws {
        let store = FakeKeyValueStore()
        let receiver = CloudBatteryReceiver(store: store)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let stored = SidecarBatteryInfo(percentage: 64, state: .unplugged)
        store.set(try encoder.encode(stored), forKey: CloudBatteryReceiver.batteryKey)

        var received: SidecarBatteryInfo?
        receiver.onBatteryUpdate = { received = $0 }
        receiver.startListening()

        XCTAssertEqual(received?.percentage, 64)
        XCTAssertEqual(received?.state, .unplugged)

        receiver.stopListening()
    }

    func testCloudBatteryReceiverIgnoresEmptyStore() {
        let receiver = CloudBatteryReceiver(store: FakeKeyValueStore())

        var received: SidecarBatteryInfo?
        receiver.onBatteryUpdate = { received = $0 }
        receiver.startListening()

        XCTAssertNil(received)
        receiver.stopListening()
    }

    @MainActor
    func testDisplayManagerViewModelBatteryBinding() async {
        class MockBatteryReceiver: BatteryReceiving {
            var onBatteryUpdate: ((SidecarBatteryInfo) -> Void)?
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
