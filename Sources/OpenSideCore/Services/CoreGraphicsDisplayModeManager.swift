import Foundation
import CoreGraphics

/// 화면이 내놓은 모드 하나. CGDisplayMode 에서 우리가 쓰는 값만 뽑은 것입니다.
///
/// 고르는 규칙을 실제 화면 없이 시험할 수 있도록 둡니다. CGDisplayMode 는 만들 수 없습니다.
struct RawDisplayMode: Equatable {
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
}

/// CoreGraphics Display Mode API를 활용한 디스플레이 해상도 조회 및 변경 서비스 구현체
public struct CoreGraphicsDisplayModeManager: DisplayModeManaging {
    public init() {}

    /// 화면이 내놓은 모드 목록에서 사용자에게 보일 것만 고릅니다.
    ///
    /// 세 가지를 합니다.
    /// - 800x600 미만을 버립니다. 그보다 작으면 쓸 수가 없습니다.
    /// - 논리 해상도가 같은 것은 하나만 남깁니다. 픽셀이 많은 쪽(HiDPI)을 고르되,
    ///   지금 쓰는 모드는 픽셀이 적어도 이깁니다. 목록에서 현재 값이 사라지면 안 됩니다.
    /// - 가로 오름차순, 가로가 같으면 세로 오름차순으로 정렬합니다.
    static func usableModes(from raw: [RawDisplayMode], current: RawDisplayMode?) -> [DisplayResolutionMode] {
        var byLogicalSize: [String: DisplayResolutionMode] = [:]

        for mode in raw {
            guard mode.width >= 800, mode.height >= 600 else { continue }

            let isCurrent = current.map {
                $0.width == mode.width && $0.height == mode.height && $0.pixelWidth == mode.pixelWidth
            } ?? false

            let candidate = DisplayResolutionMode(
                width: mode.width,
                height: mode.height,
                pixelWidth: mode.pixelWidth,
                pixelHeight: mode.pixelHeight,
                refreshRate: mode.refreshRate,
                isHiDPI: (mode.pixelWidth > mode.width) || (mode.pixelHeight > mode.height),
                isCurrent: isCurrent
            )

            let key = "\(mode.width)x\(mode.height)"
            if let existing = byLogicalSize[key] {
                if isCurrent || (!existing.isCurrent && candidate.pixelWidth > existing.pixelWidth) {
                    byLogicalSize[key] = candidate
                }
            } else {
                byLogicalSize[key] = candidate
            }
        }

        return byLogicalSize.values.sorted { first, second in
            if first.width != second.width { return first.width < second.width }
            return first.height < second.height
        }
    }

    public func getAvailableModes(displayID: CGDirectDisplayID) -> [DisplayResolutionMode] {
        let options: [CFString: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue!
        ]

        guard let allModes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode] else {
            return []
        }

        let current = CGDisplayCopyDisplayMode(displayID).map {
            RawDisplayMode(width: $0.width, height: $0.height,
                           pixelWidth: $0.pixelWidth, pixelHeight: $0.pixelHeight,
                           refreshRate: $0.refreshRate)
        }

        // 고르는 규칙은 usableModes 에 있습니다. 여기서는 CoreGraphics 에서 값만 옮깁니다.
        return Self.usableModes(
            from: allModes.map {
                RawDisplayMode(width: $0.width, height: $0.height,
                               pixelWidth: $0.pixelWidth, pixelHeight: $0.pixelHeight,
                               refreshRate: $0.refreshRate)
            },
            current: current
        )
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
        mode: DisplayResolutionMode,
        persistence: DisplayConfigurationPersistence = .permanent
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

        let scope: CGConfigureOption = persistence == .session ? .forSession : .permanently
        let completeResult = CGCompleteDisplayConfiguration(config, scope)
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
