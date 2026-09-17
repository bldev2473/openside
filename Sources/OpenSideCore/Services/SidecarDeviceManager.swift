import Foundation
import ObjectiveC

/// macOS SidecarCore 프라이빗 프레임워크를 활용한 사이드카 장비 검색 및 연결 관리자
public struct SidecarDeviceManager: @unchecked Sendable, SidecarConnecting {
    private let displayManagerClass: AnyClass?
    private let sidecarCoreLoaded: Bool

    public init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_NOW)
        self.sidecarCoreLoaded = (handle != nil)
        self.displayManagerClass = NSClassFromString("SidecarDisplayManager")
    }

    /// SidecarDisplayManager.sharedManager 획득
    private func getSharedManager() -> AnyObject? {
        guard let cls = displayManagerClass as? NSObject.Type else {
            return nil
        }
        let sel = NSSelectorFromString("sharedManager")
        guard cls.responds(to: sel) else {
            return nil
        }
        return cls.perform(sel)?.takeUnretainedValue()
    }

    /// 기기를 가리키는 안정된 식별자.
    ///
    /// 이름은 쓰지 않습니다. 사용자가 iPad 이름을 바꾸면 같은 기기가 다른 기기로 보이고,
    /// 이름이 같은 기기가 둘이면 서로 구별되지 않습니다.
    ///
    /// 읽을 수 없으면 nil 을 돌려줍니다. 임의의 값을 지어내면 폴링마다 다른 값이 나와
    /// 이 식별자를 기억해 두는 쪽이 전부 깨집니다.
    private func stableIdentifier(of device: AnyObject) -> String? {
        guard let object = device as? NSObject else { return nil }
        let idSel = NSSelectorFromString("identifier")
        guard object.responds(to: idSel),
              let raw = object.perform(idSel)?.takeUnretainedValue() else {
            return nil
        }
        if let uuid = raw as? UUID { return uuid.uuidString }
        if let text = raw as? String { return text }
        return nil
    }

    public func getAvailableDevices() -> [SidecarDeviceInfo] {
        guard let manager = getSharedManager() else {
            return []
        }

        let devicesSel = NSSelectorFromString("devices")
        let connectedSel = NSSelectorFromString("connectedDevices")
        let nameSel = NSSelectorFromString("name")

        let rawDevices = (manager.perform(devicesSel)?.takeUnretainedValue() as? [AnyObject]) ?? []
        let rawConnected = (manager.perform(connectedSel)?.takeUnretainedValue() as? [AnyObject]) ?? []

        let connectedIDs = Set(rawConnected.compactMap { stableIdentifier(of: $0) })

        return rawDevices.compactMap { dev -> SidecarDeviceInfo? in
            // 식별자가 없는 기기는 내보내지 않습니다. 연결 여부도 기억도 식별자에 걸려 있어
            // 이름만 있는 항목은 목록에 있어도 쓸 수가 없습니다.
            guard let id = stableIdentifier(of: dev) else { return nil }

            let name = (dev.perform(nameSel)?.takeUnretainedValue() as? String) ?? "알 수 없는 기기"

            return SidecarDeviceInfo(
                id: id,
                name: name,
                isConnected: connectedIDs.contains(id)
            )
        }
    }

    public func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let manager = getSharedManager() else {
            completion(.failure(NSError(domain: "OpenSide", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sidecar 서비스를 로드할 수 없습니다."])))
            return
        }

        let rawDevices = (manager.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [AnyObject]) ?? []

        // 이름이 아니라 식별자로 찾습니다. 이름이 같은 iPad 가 둘이면 이름으로는 못 가립니다.
        guard let targetDev = rawDevices.first(where: { stableIdentifier(of: $0) == device.id }) else {
            completion(.failure(NSError(domain: "OpenSide", code: -2, userInfo: [NSLocalizedDescriptionKey: "연결할 기기를 찾을 수 없습니다: \(device.name)"])))
            return
        }

        let block: @convention(block) (Error?) -> Void = { error in
            if let error { completion(.failure(error)) } else { completion(.success(())) }
        }

        let connectSel = NSSelectorFromString("connectToDevice:completion:")
        guard manager.responds(to: connectSel),
              let method = class_getInstanceMethod(type(of: manager), connectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -3, userInfo: [NSLocalizedDescriptionKey: "Sidecar 연결 메서드를 찾을 수 없습니다."])))
            return
        }
        typealias PlainConnect = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
        let fn = unsafeBitCast(method_getImplementation(method), to: PlainConnect.self)
        fn(manager, connectSel, targetDev, unsafeBitCast(block, to: AnyObject.self))
    }

    public func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let manager = getSharedManager() else {
            completion(.failure(NSError(domain: "OpenSide", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sidecar 서비스를 로드할 수 없습니다."])))
            return
        }

        let connectedSel = NSSelectorFromString("connectedDevices")
        let rawConnected = (manager.perform(connectedSel)?.takeUnretainedValue() as? [AnyObject]) ?? []

        guard let firstConnected = rawConnected.first else {
            completion(.success(()))
            return
        }

        let disconnectSel = NSSelectorFromString("disconnectFromDevice:completion:")
        guard manager.responds(to: disconnectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -3, userInfo: [NSLocalizedDescriptionKey: "Sidecar 연결 해제 메서드를 찾을 수 없습니다."])))
            return
        }

        typealias DisconnectFunc = @convention(c) (AnyObject, Selector, AnyObject, @convention(block) (Error?) -> Void) -> Void
        guard let method = class_getInstanceMethod(type(of: manager), disconnectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -4, userInfo: [NSLocalizedDescriptionKey: "연결 해제 함수 구현체를 찾을 수 없습니다."])))
            return
        }

        let imp = method_getImplementation(method)
        let disconnectFunc = unsafeBitCast(imp, to: DisconnectFunc.self)

        let block: @convention(block) (Error?) -> Void = { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }

        disconnectFunc(manager, disconnectSel, firstConnected, block)
    }
}
