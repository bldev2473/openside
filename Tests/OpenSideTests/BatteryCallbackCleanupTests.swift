import XCTest
@testable import OpenSideCore

/// 배터리 수신기는 쓰는 쪽에서 싱글턴으로 들어올 수 있다. 뷰모델이 사라져도 콜백이 남으면
/// 죽은 클로저가 계속 붙어 있게 된다.
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
            XCTAssertNotNil(receiver.onBatteryUpdate, "먼저 콜백이 걸려 있어야 한다")
            viewModel = nil
        }

        XCTAssertTrue(receiver.stopped, "수신을 멈춰야 한다")
        XCTAssertNil(receiver.onBatteryUpdate, "콜백도 비워야 한다")
    }
}
