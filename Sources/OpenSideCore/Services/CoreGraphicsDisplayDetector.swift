import Cocoa
import CoreGraphics

/// macOS CoreGraphics 및 AppKit 기반 디스플레이 감지 서비스 구현체
public struct CoreGraphicsDisplayDetector: DisplayDetecting {
    public init() {}

    public func getActiveDisplays() -> [DisplayInfo] {
        var displays: [DisplayInfo] = []

        // 1. NSScreen 정보를 통해 localizedName 및 메인 여부 매핑
        let screens = NSScreen.screens

        // 2. CoreGraphics 활성 디스플레이 ID 목록 조회
        var displayCount: UInt32 = 0
        var activeDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        let error = CGGetActiveDisplayList(16, &activeDisplayIDs, &displayCount)

        guard error == .success else {
            return []
        }

        for i in 0..<Int(displayCount) {
            let displayID = activeDisplayIDs[i]
            let bounds = CGDisplayBounds(displayID)
            let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
            let isMain = CGDisplayIsMain(displayID) != 0

            // 디스플레이 UUID 생성
            let uuidString: String
            if let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
                uuidString = CFUUIDCreateString(nil, cfUUID) as String
            } else {
                uuidString = "display-\(displayID)"
            }

            // NSScreen과 매핑하여 이름 추출
            let screen = screens.first { sc in
                let desc = sc.deviceDescription
                let num = desc[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                return num == displayID
            }

            let name = screen?.localizedName ?? (isBuiltin ? "내장 디스플레이" : "외장 디스플레이 \(displayID)")

            // 사이드카 여부 판별: 이름에 "Sidecar", "iPad", "AirPlay" 포함 및 비내장 디스플레이
            let lowerName = name.lowercased()
            let isSidecar = !isBuiltin && (
                lowerName.contains("sidecar") ||
                lowerName.contains("ipad") ||
                lowerName.contains("airplay")
            )

            let info = DisplayInfo(
                id: displayID,
                uuid: uuidString,
                name: name,
                bounds: bounds,
                isMain: isMain,
                isBuiltin: isBuiltin,
                isSidecar: isSidecar
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
