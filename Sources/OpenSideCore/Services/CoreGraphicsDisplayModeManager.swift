import Foundation
import CoreGraphics

/// CoreGraphics Display Mode API를 활용한 디스플레이 해상도 조회 및 변경 서비스 구현체
public struct CoreGraphicsDisplayModeManager: DisplayModeManaging {
    public init() {}

    public func getAvailableModes(displayID: CGDirectDisplayID) -> [DisplayResolutionMode] {
        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!
        ]

        guard let allModes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode] else {
            return []
        }

        let currentMode = getCurrentMode(displayID: displayID)

        // 논리 해상도(width x height)별로 가장 화질이 뛰어난(HiDPI 우선) 모드 선택
        var uniqueModesMap: [String: (mode: DisplayResolutionMode, rawMode: CGDisplayMode)] = [:]

        for mode in allModes {
            let width = mode.width
            let height = mode.height

            // 사용성이 떨어지는 극단적 저해상도(800x600 미만: 400x300, 512x384, 640x480 등) 필터링
            guard width >= 800, height >= 600 else {
                continue
            }

            let pixelW = mode.pixelWidth
            let pixelH = mode.pixelHeight
            let refresh = mode.refreshRate
            let isHiDPI = (pixelW > width) || (pixelH > height)

            let isCurrent = (currentMode?.width == width && currentMode?.height == height && currentMode?.pixelWidth == pixelW)

            let key = "\(width)x\(height)"
            let candidate = DisplayResolutionMode(
                width: width,
                height: height,
                pixelWidth: pixelW,
                pixelHeight: pixelH,
                refreshRate: refresh,
                isHiDPI: isHiDPI,
                isCurrent: isCurrent
            )

            if let existing = uniqueModesMap[key] {
                // 현재 모드이거나, 기존 모드보다 픽셀 수가 더 많으면(HiDPI) 대체
                if isCurrent || (candidate.pixelWidth > existing.mode.pixelWidth) {
                    uniqueModesMap[key] = (candidate, mode)
                }
            } else {
                uniqueModesMap[key] = (candidate, mode)
            }
        }

        // 가로 해상도 기준 오름차순 정렬
        return uniqueModesMap.values.map { $0.mode }.sorted { mode1, mode2 in
            if mode1.width != mode2.width {
                return mode1.width < mode2.width
            }
            return mode1.height < mode2.height
        }
    }

    public func getCurrentMode(displayID: CGDirectDisplayID) -> DisplayResolutionMode? {
        guard let mode = CGDisplayCopyDisplayMode(displayID) else {
            return nil
        }

        let width = mode.width
        let height = mode.height
        let pixelW = mode.pixelWidth
        let pixelH = mode.pixelHeight
        let refresh = mode.refreshRate
        let isHiDPI = (pixelW > width) || (pixelH > height)

        return DisplayResolutionMode(
            width: width,
            height: height,
            pixelWidth: pixelW,
            pixelHeight: pixelH,
            refreshRate: refresh,
            isHiDPI: isHiDPI,
            isCurrent: true
        )
    }

    public func setDisplayResolution(
        displayID: CGDirectDisplayID,
        mode: DisplayResolutionMode
    ) -> Result<Void, DisplayConfigurationError> {
        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!
        ]

        guard let allModes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode] else {
            return .failure(.configureOriginFailed(code: -1))
        }

        // 대상 CGDisplayMode 검색 (픽셀 크기까지 일치하는 HiDPI 우선)
        guard let targetCGMode = allModes.first(where: {
            $0.width == mode.width &&
            $0.height == mode.height &&
            $0.pixelWidth == mode.pixelWidth &&
            $0.pixelHeight == mode.pixelHeight
        }) ?? allModes.first(where: {
            $0.width == mode.width && $0.height == mode.height
        }) else {
            return .failure(.configureOriginFailed(code: -2))
        }

        var configRef: CGDisplayConfigRef?
        let beginResult = CGBeginDisplayConfiguration(&configRef)
        guard beginResult == .success, let config = configRef else {
            return .failure(.beginConfigurationFailed(code: beginResult.rawValue))
        }

        let configureResult = CGConfigureDisplayWithDisplayMode(config, displayID, targetCGMode, nil)
        guard configureResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.configureOriginFailed(code: configureResult.rawValue))
        }

        let completeResult = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.completeConfigurationFailed(code: completeResult.rawValue))
        }

        return .success(())
    }

    public func canToggleHiDPI(displayID: CGDirectDisplayID) -> Bool {
        guard let current = getCurrentMode(displayID: displayID) else {
            return false
        }

        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!
        ]
        guard let allModes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode] else {
            return false
        }

        let matchingModes = allModes.filter { $0.width == current.width && $0.height == current.height }
        let hasHiDPI = matchingModes.contains { $0.pixelWidth > $0.width || $0.pixelHeight > $0.height }
        let hasStandard = matchingModes.contains { $0.pixelWidth == $0.width && $0.pixelHeight == $0.height }

        return hasHiDPI && hasStandard
    }

    public func toggleHiDPI(displayID: CGDirectDisplayID, enable: Bool) -> Result<Void, DisplayConfigurationError> {
        guard let current = getCurrentMode(displayID: displayID) else {
            return .failure(.configureOriginFailed(code: -1))
        }

        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!
        ]
        guard let allModes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode] else {
            return .failure(.configureOriginFailed(code: -1))
        }

        let matchingModes = allModes.filter { $0.width == current.width && $0.height == current.height }

        let targetMode: CGDisplayMode?
        if enable {
            targetMode = matchingModes.first { $0.pixelWidth > $0.width || $0.pixelHeight > $0.height }
        } else {
            targetMode = matchingModes.first { $0.pixelWidth == $0.width && $0.pixelHeight == $0.height }
        }

        guard let targetCGMode = targetMode else {
            return .failure(.configureOriginFailed(code: -2))
        }

        var configRef: CGDisplayConfigRef?
        let beginResult = CGBeginDisplayConfiguration(&configRef)
        guard beginResult == .success, let config = configRef else {
            return .failure(.beginConfigurationFailed(code: beginResult.rawValue))
        }

        let configureResult = CGConfigureDisplayWithDisplayMode(config, displayID, targetCGMode, nil)
        guard configureResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.configureOriginFailed(code: configureResult.rawValue))
        }

        let completeResult = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.completeConfigurationFailed(code: completeResult.rawValue))
        }

        return .success(())
    }
}
