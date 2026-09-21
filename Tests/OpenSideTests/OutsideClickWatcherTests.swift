import XCTest
@testable import OpenSideCore

/// 바깥 클릭 감시는 팝오버가 떠 있는 동안만 돌아야 한다.
/// 계속 켜 두면 앱이 쓰이지 않는 내내 전역 이벤트를 받는다.
@MainActor
final class OutsideClickWatcherTests: XCTestCase {

    /// 실제 NSEvent 대신 가짜 등록기를 넣어, 등록과 해제가 짝이 맞는지 본다.
    @MainActor
    private final class Spy {
        var started = 0
        var stopped = 0
        var handler: (() -> Void)?

        func makeWatcher() -> OutsideClickWatcher {
            OutsideClickWatcher(
                start: { [weak self] fire in
                    self?.started += 1
                    self?.handler = fire
                    return "token" as NSString
                },
                stop: { [weak self] _ in self?.stopped += 1 }
            )
        }
    }

    func testDoesNotWatchUntilAsked() {
        let spy = Spy()
        _ = spy.makeWatcher()
        XCTAssertEqual(spy.started, 0)
    }

    func testBeginRegistersOnceAndEndRemoves() {
        let spy = Spy()
        let watcher = spy.makeWatcher()

        watcher.begin {}
        XCTAssertTrue(watcher.isWatching)
        XCTAssertEqual(spy.started, 1)

        watcher.end()
        XCTAssertFalse(watcher.isWatching)
        XCTAssertEqual(spy.stopped, 1)
    }

    /// 팝오버를 연달아 열어도 감시가 겹쳐 쌓이면 안 된다.
    func testBeginTwiceRegistersOnlyOnce() {
        let spy = Spy()
        let watcher = spy.makeWatcher()
        watcher.begin {}
        watcher.begin {}
        XCTAssertEqual(spy.started, 1)
    }

    /// 켜지 않았는데 끄라고 해도 조용히 넘어간다.
    func testEndWithoutBeginDoesNothing() {
        let spy = Spy()
        spy.makeWatcher().end()
        XCTAssertEqual(spy.stopped, 0)
    }

    func testTheClickReachesTheCaller() {
        let spy = Spy()
        let watcher = spy.makeWatcher()
        var clicked = 0
        watcher.begin { clicked += 1 }

        spy.handler?()

        XCTAssertEqual(clicked, 1)
    }
}
