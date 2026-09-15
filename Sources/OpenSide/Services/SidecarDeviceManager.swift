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

    public func getAvailableDevices() -> [SidecarDeviceInfo] {
        guard let manager = getSharedManager() else {
            return []
        }

        let devicesSel = NSSelectorFromString("devices")
        let connectedSel = NSSelectorFromString("connectedDevices")

        let rawDevices = (manager.perform(devicesSel)?.takeUnretainedValue() as? [AnyObject]) ?? []
        let rawConnected = (manager.perform(connectedSel)?.takeUnretainedValue() as? [AnyObject]) ?? []

        let connectedNames = Set(rawConnected.compactMap { dev -> String? in
            let nameSel = NSSelectorFromString("name")
            return dev.perform(nameSel)?.takeUnretainedValue() as? String
        })

        var result: [SidecarDeviceInfo] = []

        for dev in rawDevices {
            let nameSel = NSSelectorFromString("name")
            let idSel = NSSelectorFromString("identifier")

            let name = (dev.perform(nameSel)?.takeUnretainedValue() as? String) ?? "알 수 없는 기기"
            let idObj = dev.perform(idSel)?.takeUnretainedValue()
            let idString: String
            if let uuid = idObj as? UUID {
                idString = uuid.uuidString
            } else if let idObj = idObj {
                idString = String(describing: idObj)
            } else {
                idString = UUID().uuidString
            }

            let isConnected = connectedNames.contains(name)

            result.append(SidecarDeviceInfo(
                id: idString,
                name: name,
                isConnected: isConnected
            ))
        }

        return result
    }

    public func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let manager = getSharedManager() else {
            completion(.failure(NSError(domain: "OpenSide", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sidecar 서비스를 로드할 수 없습니다."])))
            return
        }

        let devicesSel = NSSelectorFromString("devices")
        let rawDevices = (manager.perform(devicesSel)?.takeUnretainedValue() as? [AnyObject]) ?? []

        // 이름 또는 ID로 대상 디바이스 검색
        guard let targetDev = rawDevices.first(where: { dev in
            let nameSel = NSSelectorFromString("name")
            let devName = dev.perform(nameSel)?.takeUnretainedValue() as? String
            return devName == device.name
        }) else {
            completion(.failure(NSError(domain: "OpenSide", code: -2, userInfo: [NSLocalizedDescriptionKey: "연결할 기기를 찾을 수 없습니다: \(device.name)"])))
            return
        }

        let connectSel = NSSelectorFromString("connectToDevice:completion:")
        guard manager.responds(to: connectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -3, userInfo: [NSLocalizedDescriptionKey: "Sidecar 연결 메서드를 찾을 수 없습니다."])))
            return
        }

        typealias ConnectFunc = @convention(c) (AnyObject, Selector, AnyObject, @convention(block) (Error?) -> Void) -> Void
        guard let method = class_getInstanceMethod(type(of: manager), connectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -4, userInfo: [NSLocalizedDescriptionKey: "연결 함수 구현체를 찾을 수 없습니다."])))
            return
        }

        let imp = method_getImplementation(method)
        let connectFunc = unsafeBitCast(imp, to: ConnectFunc.self)

        let block: @convention(block) (Error?) -> Void = { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }

        connectFunc(manager, connectSel, targetDev, block)
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
