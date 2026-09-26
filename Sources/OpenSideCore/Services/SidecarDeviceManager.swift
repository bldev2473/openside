import Foundation
import ObjectiveC

/// Sidecar device discovery and connection manager utilizing macOS private SidecarCore framework
public struct SidecarDeviceManager: @unchecked Sendable, SidecarConnecting {
    private let displayManagerClass: AnyClass?
    private let sidecarCoreLoaded: Bool

    public init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_NOW)
        self.sidecarCoreLoaded = (handle != nil)
        self.displayManagerClass = NSClassFromString("SidecarDisplayManager")
    }

    /// Obtains SidecarDisplayManager.sharedManager
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

    /// Stable unique identifier for a device.
    ///
    /// Device names are not used. Renaming an iPad would make it appear as a new device,
    /// and identical names cannot be distinguished.
    ///
    /// Returns nil if unreadable. Synthesizing random values would produce different IDs per poll,
    /// breaking components that remember device IDs.
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
            // Exclude devices without identifiers. Connection status and persistence depend on IDs,
            // so an entry with only a name cannot be managed reliably.
            guard let id = stableIdentifier(of: dev) else { return nil }

            let name = (dev.perform(nameSel)?.takeUnretainedValue() as? String) ?? "Unknown Device"

            return SidecarDeviceInfo(
                id: id,
                name: name,
                isConnected: connectedIDs.contains(id)
            )
        }
    }

    public func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let manager = getSharedManager() else {
            completion(.failure(NSError(domain: "OpenSide", code: -1, userInfo: [NSLocalizedDescriptionKey: "The Sidecar service could not be loaded."])))
            return
        }

        let rawDevices = (manager.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [AnyObject]) ?? []

        // Search by identifier, not name, to disambiguate devices with identical names.
        guard let targetDev = rawDevices.first(where: { stableIdentifier(of: $0) == device.id }) else {
            completion(.failure(NSError(domain: "OpenSide", code: -2, userInfo: [NSLocalizedDescriptionKey: "No such device to connect to: \(device.name)"])))
            return
        }

        let block: @convention(block) (Error?) -> Void = { error in
            if let error { completion(.failure(error)) } else { completion(.success(())) }
        }

        let connectSel = NSSelectorFromString("connectToDevice:completion:")
        guard manager.responds(to: connectSel),
              let method = class_getInstanceMethod(type(of: manager), connectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -3, userInfo: [NSLocalizedDescriptionKey: "The Sidecar connect method could not be found."])))
            return
        }
        typealias PlainConnect = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
        let fn = unsafeBitCast(method_getImplementation(method), to: PlainConnect.self)
        fn(manager, connectSel, targetDev, unsafeBitCast(block, to: AnyObject.self))
    }

    public func currentSessionInfo() -> SidecarSessionInfo? {
        guard let manager = getSharedManager() else { return nil }

        let connected = (manager.perform(NSSelectorFromString("connectedDevices"))?.takeUnretainedValue() as? [AnyObject]) ?? []
        guard let device = connected.first else { return nil }

        let configSel = NSSelectorFromString("configForDevice:")
        guard manager.responds(to: configSel),
              let config = manager.perform(configSel, with: device)?.takeUnretainedValue() as? NSObject else {
            return nil
        }

        // configForDevice: returns nil when disconnected; reaching here guarantees an active session.
        func number(_ key: String) -> Int? { (config.value(forKey: key) as? NSNumber)?.intValue }
        guard let framerate = number("framerate"),
              let minimumBitrate = number("txMinBitrate"),
              let maximumBitrate = number("txMaxBitrate"),
              let scale = number("scale"),
              let size = config.value(forKey: "size") as? NSValue else {
            return nil
        }

        let logical = size.sizeValue
        return SidecarSessionInfo(
            framerate: framerate,
            minimumBitrate: minimumBitrate,
            maximumBitrate: maximumBitrate,
            width: Int(logical.width),
            height: Int(logical.height),
            scale: scale,
            isHDR: (number("hdr") ?? 0) != 0
        )
    }

    public func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let manager = getSharedManager() else {
            completion(.failure(NSError(domain: "OpenSide", code: -1, userInfo: [NSLocalizedDescriptionKey: "The Sidecar service could not be loaded."])))
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
            completion(.failure(NSError(domain: "OpenSide", code: -3, userInfo: [NSLocalizedDescriptionKey: "The Sidecar disconnect method could not be found."])))
            return
        }

        typealias DisconnectFunc = @convention(c) (AnyObject, Selector, AnyObject, @convention(block) (Error?) -> Void) -> Void
        guard let method = class_getInstanceMethod(type(of: manager), disconnectSel) else {
            completion(.failure(NSError(domain: "OpenSide", code: -4, userInfo: [NSLocalizedDescriptionKey: "The disconnect implementation could not be found."])))
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
