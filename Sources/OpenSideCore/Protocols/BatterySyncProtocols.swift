import Foundation

/// 사이드카 배터리 정보 수신 인터페이스
public protocol BatteryReceiving: AnyObject {
    /// 배터리 정보 수신 시 호출될 콜백 클로저
    var onBatteryUpdate: ((SidecarBatteryInfo) -> Void)? { get set }

    /// 배터리 정보 수신 서비스 시작
    func startListening()

    /// 배터리 정보 수신 서비스 종료
    func stopListening()
}
