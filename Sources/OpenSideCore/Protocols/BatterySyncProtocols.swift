import Foundation

/// 키-값 저장소 추상화. 실제 구현은 `NSUbiquitousKeyValueStore`이며 테스트에서는 대역으로 대체합니다.
public protocol KeyValueStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    @discardableResult
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueStoring {}

/// 사이드카 배터리 정보 수신 인터페이스
public protocol BatteryReceiving: AnyObject {
    /// 배터리 정보 수신 시 호출될 콜백 클로저
    var onBatteryUpdate: ((SidecarBatteryInfo) -> Void)? { get set }

    /// 배터리 정보 수신 서비스 시작
    func startListening()

    /// 배터리 정보 수신 서비스 종료
    func stopListening()
}
