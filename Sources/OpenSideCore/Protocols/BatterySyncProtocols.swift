import Foundation

/// 사이드카 배터리 정보 수신 인터페이스
public protocol BatteryReceiving: AnyObject {
    /// 배터리 정보 수신 시 호출될 콜백 클로저.
    /// iPad 를 더 이상 읽을 수 없으면 nil 을 넘긴다. 그래야 화면이 옛 값을 계속 보여주지 않는다.
    var onBatteryUpdate: ((SidecarBatteryInfo?) -> Void)? { get set }

    /// 배터리 정보 수신 서비스 시작
    func startListening()

    /// 배터리 정보 수신 서비스 종료
    func stopListening()
}

/// 남은 사용 시간 추정 인터페이스.
///
/// 과거 세션이 있어야 추정할 수 있으므로 구현체는 쓰는 앱이 넣는다.
public protocol RemainingTimeEstimating: AnyObject {
    /// 현재 잔량으로 얼마나 더 쓸 수 있는지(초). 표본이 모자라면 nil.
    func estimatedRemaining(currentBattery: Int) -> TimeInterval?
}
