import XCTest
@testable import OpenSideCore

/// Battery receivers may be injected as singletons. If callbacks remain after view model deallocation,
/// a dead closure would be retained.
final class BatteryCallbackCleanupTests: XCTestCase {

    final class SpyReceiver: BatteryReceiving, @unchecked Sendable {
        var onBatteryUpdate: ((SidecarBatteryInfo?) -> Void)?
        var stopped = false
        func startListening() {}
        func stopListening() { stopped = true }
    }

    @MainActor
    func testClearsTheBatteryCallbackWhenTheViewModelGoesAway() {
        let receiver = SpyReceiver()

        autoreleasepool {
            var viewModel: DisplayManagerViewModel? = DisplayManagerViewModel(
                detector: ManagedDisplayTests.TwoDisplayDetector(),
                readinessChecker: ManagedDisplayTests.QuietChecker(),
                batteryReceiver: receiver
            )
            XCTAssertNotNil(viewModel)
            XCTAssertNotNil(receiver.onBatteryUpdate, "Callback should be attached initially")
            viewModel = nil
        }

        XCTAssertTrue(receiver.stopped, "Listening should be stopped")
        XCTAssertNil(receiver.onBatteryUpdate, "Callback should also be cleared")
    }
}
