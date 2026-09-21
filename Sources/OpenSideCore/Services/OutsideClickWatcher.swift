import AppKit

/// 팝오버 바깥을 클릭했는지 지켜본다.
///
/// 팝오버는 `.transient` 라 원래 바깥을 누르면 닫혀야 합니다. 그런데 이 앱은 메뉴바에만
/// 있는 앱이라 아이콘을 눌러도 활성 앱이 되지 않을 때가 있고, 그러면 바깥 클릭이 팝오버까지
/// 닿지 않아 열린 채로 남습니다. 전역으로 한 번 더 지켜보다 직접 닫습니다.
///
/// 전역 감시는 다른 앱으로 가는 이벤트만 받습니다. 즉 여기 걸리는 클릭은 정의상 바깥입니다.
/// 마우스 이벤트라 손쉬운 사용 권한이 필요하지 않습니다.
@MainActor
public final class OutsideClickWatcher {

    /// 감시를 시작하고 해제에 쓸 표를 돌려줍니다. 시험에서 갈아 끼웁니다.
    public typealias Start = (@escaping () -> Void) -> Any?
    /// 표를 받아 감시를 멈춥니다.
    public typealias Stop = (Any) -> Void

    private let start: Start
    private let stop: Stop
    private var token: Any?

    /// 지금 지켜보고 있는지.
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
        // 여기서는 메인 액터로 갈 수 없으므로, 쓰는 쪽이 팝오버를 닫을 때 end() 를 부릅니다.
    }

    /// 바깥 클릭을 지켜보기 시작합니다. 이미 지켜보고 있으면 아무 일도 하지 않습니다.
    public func begin(_ onOutsideClick: @escaping () -> Void) {
        guard token == nil else { return }
        token = start(onOutsideClick)
    }

    /// 감시를 멈춥니다. 켜지 않았으면 아무 일도 하지 않습니다.
    public func end() {
        guard let token else { return }
        stop(token)
        self.token = nil
    }
}
