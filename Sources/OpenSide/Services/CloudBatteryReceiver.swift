import Foundation

/// iCloud 키-값 저장소를 통해 iPad 컴패니언 앱의 배터리 정보를 수신하는 서비스
public final class CloudBatteryReceiver: BatteryReceiving {
    public static let shared = CloudBatteryReceiver()

    /// 컴패니언 앱과 공유하는 키-값 저장소 키. 양쪽 앱에서 동일해야 합니다.
    public static let batteryKey = "org.openside.sidecarBattery"

    public var onBatteryUpdate: ((SidecarBatteryInfo) -> Void)?

    private let store: KeyValueStoring
    private var changeObserver: NSObjectProtocol?

    public init(store: KeyValueStoring = NSUbiquitousKeyValueStore.default) {
        self.store = store
    }

    deinit {
        stopListening()
    }

    /// iCloud 변경 알림 구독을 시작하고 저장된 최신 값을 즉시 반영합니다.
    public func startListening() {
        guard changeObserver == nil else { return }

        changeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleExternalChange(notification)
        }

        store.synchronize()
        emitStoredBattery()
    }

    /// iCloud 변경 알림 구독을 해제합니다.
    public func stopListening() {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        changeObserver = nil
    }

    private func handleExternalChange(_ notification: Notification) {
        // 계정 전환·초기 동기화 시에는 변경 키 목록이 없으므로 그때도 값을 재확인합니다.
        if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
           !changedKeys.contains(Self.batteryKey) {
            return
        }

        emitStoredBattery()
    }

    private func emitStoredBattery() {
        guard let data = store.data(forKey: Self.batteryKey) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let battery = try? decoder.decode(SidecarBatteryInfo.self, from: data) else { return }

        onBatteryUpdate?(battery)
    }
}
