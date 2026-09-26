import AppKit

/// Monitors mouse clicks outside the popover.
///
/// Popovers configured as `.transient` should close when clicking outside. However, because this
/// app lives exclusively in the menu bar, clicking the status item does not always activate the app.
/// When not active, outside clicks may fail to reach the popover, leaving it open. A global monitor ensures it closes.
///
/// Global monitors only receive events destined for other applications, meaning captured clicks are outside by definition.
/// Because these are mouse events, Accessibility permissions are not required.
@MainActor
public final class OutsideClickWatcher {

    /// Starts monitoring and returns a token used to stop. Swapped in tests.
    public typealias Start = (@escaping () -> Void) -> Any?
    /// Takes the token and stops monitoring.
    public typealias Stop = (Any) -> Void

    private let start: Start
    private let stop: Stop
    private var token: Any?

    /// Whether monitoring is currently active.
    public var isWatching: Bool { token != nil }

    public init(
        start: @escaping Start = { fire in
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
                fire()
            }
        },
        stop: @escaping Stop = { NSEvent.removeMonitor($0) }
    ) {
        self.start = start
        self.stop = stop
    }

    deinit {
        // Cannot hop to MainActor in deinit; caller invokes end() when closing the popover.
    }

    /// Starts watching for outside clicks. No-op if already watching.
    public func begin(_ onOutsideClick: @escaping () -> Void) {
        guard token == nil else { return }
        token = start(onOutsideClick)
    }

    /// Stops watching. No-op if not currently watching.
    public func end() {
        guard let token else { return }
        stop(token)
        self.token = nil
    }
}
