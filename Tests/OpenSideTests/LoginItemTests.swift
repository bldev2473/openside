import XCTest
@testable import OpenSideCore

/// Login item toggle must track the state actually registered with the system.
/// If relying on a cached storage value, it would remain enabled even if registration failed or user disabled it in System Settings.
final class LoginItemTests: XCTestCase {

    final class StubService: LoginItemManaging, @unchecked Sendable {
        var current: LoginItemState
        var failWith: Error?
        /// State assumed after enabling (macOS may place it in needsApproval).
        var stateAfterEnabling: LoginItemState = .on
        var calls: [Bool] = []
        init(enabled: Bool) { self.current = enabled ? .on : .off }

        var state: LoginItemState { current }
        func setEnabled(_ wanted: Bool) throws {
            calls.append(wanted)
            if let failWith { throw failWith }
            current = wanted ? stateAfterEnabling : .off
        }
    }

    struct Refused: LocalizedError {
        var errorDescription: String? { "Registration refused" }
    }

    @MainActor
    func testReadsTheSystemStateRatherThanAStoredFlag() {
        XCTAssertTrue(LoginItemToggle(service: StubService(enabled: true)).isOn)
        XCTAssertFalse(LoginItemToggle(service: StubService(enabled: false)).isOn)
    }

    @MainActor
    func testTurningItOnRegisters() {
        let service = StubService(enabled: false)
        let toggle = LoginItemToggle(service: service)
        toggle.set(true)
        XCTAssertEqual(service.calls, [true])
        XCTAssertTrue(toggle.isOn)
        XCTAssertNil(toggle.failure)
    }

    @MainActor
    func testTurningItOffUnregisters() {
        let service = StubService(enabled: true)
        let toggle = LoginItemToggle(service: service)
        toggle.set(false)
        XCTAssertEqual(service.calls, [false])
        XCTAssertFalse(toggle.isOn)
    }

    /// Does not pretend to be enabled if registration fails. Reverts immediately and preserves error reason.
    @MainActor
    func testAFailedRegistrationLeavesTheToggleOff() {
        let service = StubService(enabled: false)
        service.failWith = Refused()
        let toggle = LoginItemToggle(service: service)

        toggle.set(true)

        XCTAssertFalse(toggle.isOn, "Must not stay enabled if registration failed")
        XCTAssertEqual(toggle.failure, "Registration refused")
    }

    /// If disabled via System Settings, must synchronize when settings window is refreshed.
    @MainActor
    func testFollowsAChangeMadeOutsideTheApp() {
        let service = StubService(enabled: true)
        let toggle = LoginItemToggle(service: service)
        XCTAssertTrue(toggle.isOn)

        service.current = .off
        toggle.refresh()

        XCTAssertFalse(toggle.isOn)
    }

    /// macOS may accept registration but wait for user approval in System Settings.
    /// No error occurs in this state; turning the toggle off without explanation would leave users confused.
    @MainActor
    func testApprovalPendingKeepsTheToggleOnAndSaysWhy() {
        let service = StubService(enabled: false)
        service.stateAfterEnabling = .needsApproval
        let toggle = LoginItemToggle(service: service)

        toggle.set(true)

        XCTAssertTrue(toggle.isOn, "Registration succeeded, so keep toggle enabled")
        XCTAssertTrue(toggle.needsApproval)
        XCTAssertNil(toggle.failure, "Not an error")
    }

    /// Approval notice dismisses once approved.
    @MainActor
    func testTheApprovalNoticeGoesAwayOnceApproved() {
        let service = StubService(enabled: false)
        service.stateAfterEnabling = .needsApproval
        let toggle = LoginItemToggle(service: service)
        toggle.set(true)
        XCTAssertTrue(toggle.needsApproval)

        service.current = .on
        toggle.refresh()

        XCTAssertTrue(toggle.isOn)
        XCTAssertFalse(toggle.needsApproval)
    }

    /// Clears any preceding failure notice upon successful registration.
    @MainActor
    func testClearsAnEarlierFailure() {
        let service = StubService(enabled: false)
        service.failWith = Refused()
        let toggle = LoginItemToggle(service: service)
        toggle.set(true)
        XCTAssertNotNil(toggle.failure)

        service.failWith = nil
        toggle.set(true)
        XCTAssertNil(toggle.failure)
        XCTAssertTrue(toggle.isOn)
    }
}
