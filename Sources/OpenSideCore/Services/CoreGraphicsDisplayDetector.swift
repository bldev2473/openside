import Cocoa
import CoreGraphics

/// macOS CoreGraphics 및 AppKit 기반 디스플레이 감지 서비스 구현체
public struct CoreGraphicsDisplayDetector: DisplayDetecting {
    /// 이 앱이 만든 디스플레이를 알려주는 쪽. 쓰는 앱이 넣습니다. 안 넣으면 nil 입니다.
    private let managedDisplays: ManagedDisplayReporting?

    public init(managedDisplays: ManagedDisplayReporting? = nil) {
        self.managedDisplays = managedDisplays
    }

    public func getActiveDisplays() -> [DisplayInfo] {
        var displays: [DisplayInfo] = []

        // 1. NSScreen 정보를 통해 localizedName 및 메인 여부 매핑
        let screens = NSScreen.screens

        // 2. CoreGraphics 디스플레이 ID 목록 조회
        //
        // 활성 목록이 아니라 온라인 목록을 씁니다. 복제 중인 디스플레이는 활성 목록에서
        // 빠지기 때문입니다(측정: 미러링을 켜면 active=[1], online=[1, 9]). 활성 목록만
        // 보면 iPad 를 복제로 쓰는 동안 사이드카가 끊긴 것으로 보입니다.
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

            let name = screen?.localizedName ?? (isBuiltin ? "Built-in Display" : "External Display \(displayID)")

            // 사이드카 여부 판별: 이름에 "Sidecar", "iPad", "AirPlay" 포함 및 비내장 디스플레이
            let lowerName = name.lowercased()
            let nameLooksLikeSidecar = lowerName.contains("sidecar") ||
                lowerName.contains("ipad") ||
                lowerName.contains("airplay")

            // 복제 중에는 NSScreen 이 이 화면을 내놓지 않아 이름을 못 찾습니다. 그러면
            // 이름 판별이 실패하므로 복제 중인 비내장 디스플레이는 사이드카로 봅니다.
            // 이 앱이 복제를 켜는 대상은 사이드카뿐입니다.
            let mirrorSource = CGDisplayMirrorsDisplay(displayID)
            let isMirrored = mirrorSource != kCGNullDirectDisplay
            // 이 앱이 만든 화면은 사이드카가 아닙니다. 그것도 비내장이고 NSScreen 이 이름을
            // 내놓지 않아 위 규칙에 그대로 걸리므로, 만든 쪽이 알려준 식별자로 먼저 가릅니다.
            let isOurs = managedDisplays?.managedDisplayID == displayID
            let isSidecar = !isBuiltin && !isOurs && (nameLooksLikeSidecar || isMirrored)

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
