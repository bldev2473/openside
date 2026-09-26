import Cocoa
import CoreGraphics

/// macOS CoreGraphics and AppKit based display detection service implementation
public struct CoreGraphicsDisplayDetector: DisplayDetecting {
    /// Provider of displays managed by this app. Injected by consuming apps, or nil.
    private let managedDisplays: ManagedDisplayReporting?

    /// Component to query whether an active Sidecar session exists.
    ///
    /// Used to disambiguate unnamed mirrored displays. Without an active session, such displays cannot be Sidecar.
    /// If omitted, treated as having no session.
    private let sidecar: SidecarConnecting?

    public init(
        managedDisplays: ManagedDisplayReporting? = nil,
        sidecar: SidecarConnecting? = SidecarDeviceManager()
    ) {
        self.managedDisplays = managedDisplays
        self.sidecar = sidecar
    }

    public func getActiveDisplays() -> [DisplayInfo] {
        var displays: [DisplayInfo] = []

        // Read session status once rather than per display. If the value changes while iterating,
        // different judgements could occur within the same list.
        let hasSidecarSession = sidecar?.currentSessionInfo() != nil

        // 1. Map localizedName and main display status via NSScreen info
        let screens = NSScreen.screens

        // 2. Query CoreGraphics online display IDs
        //
        // Query online displays rather than active displays. Mirrored displays are removed
        // from the active display list (observed: when mirroring is enabled, active=[1], online=[1, 9]).
        // Relying solely on active displays would make Sidecar appear disconnected while mirrored.
        var displayCount: UInt32 = 0
        var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        let error = CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount)

        guard error == .success else {
            return []
        }

        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplayIDs[i]
            let bounds = CGDisplayBounds(displayID)
            let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
            let isMain = CGDisplayIsMain(displayID) != 0

            // Generate display UUID
            let uuidString: String
            if let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
                uuidString = CFUUIDCreateString(nil, cfUUID) as String
            } else {
                uuidString = "display-\(displayID)"
            }

            // Extract display name by mapping with NSScreen
            let screen = screens.first { sc in
                let desc = sc.deviceDescription
                let num = desc[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                return num == displayID
            }

            let name = screen?.localizedName ?? (isBuiltin ? "Built-in Display" : "External Display \(displayID)")

            let mirrorSource = CGDisplayMirrorsDisplay(displayID)
            let isMirrored = mirrorSource != kCGNullDirectDisplay
            // Virtual displays created by this app are not Sidecar. Being non-builtin and unnamed
            // by NSScreen, they match the heuristic unless explicitly excluded by the creator's ID.
            let isOurs = managedDisplays?.managedDisplayID == displayID

            // Identification heuristics live in SidecarDisplayRule. Here we only collect values.
            let isSidecar = SidecarDisplayRule.isSidecar(
                name: name,
                isBuiltin: isBuiltin,
                isOurs: isOurs,
                isMirrored: isMirrored,
                hasSidecarSession: hasSidecarSession
            )

            let info = DisplayInfo(
                id: displayID,
                uuid: uuidString,
                name: name,
                bounds: bounds,
                isMain: isMain,
                isBuiltin: isBuiltin,
                isSidecar: isSidecar,
                mirrorSourceID: isMirrored ? mirrorSource : nil
            )
            displays.append(info)
        }

        return displays
    }

    public func getSidecarDisplay() -> DisplayInfo? {
        let displays = getActiveDisplays()
        return displays.first { $0.isSidecar }
    }

    public func getMainDisplay() -> DisplayInfo? {
        let displays = getActiveDisplays()
        return displays.first { $0.isMain }
    }
}
