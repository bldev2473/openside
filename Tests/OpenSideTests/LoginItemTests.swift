import XCTest
@testable import OpenSideCore

/// 로그인 항목 토글은 시스템에 실제로 등록된 상태를 따라야 한다.
/// 저장해 둔 값을 켜 두면, 등록이 실패했거나 사용자가 시스템 설정에서 꺼도 켜진 채로 남는다.
final class LoginItemTests: XCTestCase {

    final class StubService: LoginItemManaging, @unchecked Sendable {
        var current: LoginItemState
        var failWith: Error?
        /// 켠 뒤에 어떤 상태가 되는지. macOS 는 승인 대기로 두기도 한다.
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
        var errorDescription: String? { "등록을 거부당함" }
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

    /// 실패하면 켜진 척하지 않는다. 그 자리에서 되돌아오고 이유를 남긴다.
    @MainActor
    func testAFailedRegistrationLeavesTheToggleOff() {
        let service = StubService(enabled: false)
        service.failWith = Refused()
        let toggle = LoginItemToggle(service: service)

        toggle.set(true)

        XCTAssertFalse(toggle.isOn, "등록이 안 됐으면 켜져 있으면 안 된다")
        XCTAssertEqual(toggle.failure, "등록을 거부당함")
    }

    /// 시스템 설정에서 꺼 버린 경우. 창을 다시 열면 따라가야 한다.
    @MainActor
    func testFollowsAChangeMadeOutsideTheApp() {
        let service = StubService(enabled: true)
        let toggle = LoginItemToggle(service: service)
        XCTAssertTrue(toggle.isOn)

        service.current = .off
        toggle.refresh()

        XCTAssertFalse(toggle.isOn)
    }

    /// macOS 는 등록을 받아들이고도 사용자가 시스템 설정에서 켜 줄 때까지 기다린다.
    /// 그때 오류는 없다. 칸만 꺼 두면 왜 안 되는지 알 길이 없다.
    @MainActor
    func testApprovalPendingKeepsTheToggleOnAndSaysWhy() {
        let service = StubService(enabled: false)
        service.stateAfterEnabling = .needsApproval
        let toggle = LoginItemToggle(service: service)

        toggle.set(true)

        XCTAssertTrue(toggle.isOn, "등록은 됐으므로 켜진 채로 둔다")
        XCTAssertTrue(toggle.needsApproval)
        XCTAssertNil(toggle.failure, "오류가 난 것이 아니다")
    }

    /// 승인까지 끝나면 안내가 사라진다.
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

    /// 성공한 뒤에는 남아 있던 실패 표시를 지운다.
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
