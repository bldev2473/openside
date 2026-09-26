import XCTest
@testable import OpenSideCore

/// Outside click monitoring should run only while the popover is visible.
/// Keeping it active permanently receives global events even when the app is idle.
@MainActor
final class OutsideClickWatcherTests: XCTestCase {

    /// Injects a spy registrar instead of real NSEvent to verify registration and teardown pairing.
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

    /// Multiple successive popover openings must not stack redundant monitors.
    func testBeginTwiceRegistersOnlyOnce() {
        let spy = Spy()
        let watcher = spy.makeWatcher()
        watcher.begin {}
        watcher.begin {}
        XCTAssertEqual(spy.started, 1)
    }

    /// Calling end without begin fails gracefully.
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
