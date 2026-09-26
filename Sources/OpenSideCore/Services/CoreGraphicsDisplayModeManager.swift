import Foundation
import CoreGraphics

/// A single display mode exposing only values used by this app.
///
/// Kept separate so selection rules can be tested without physical displays. CGDisplayMode cannot be instantiated directly.
struct RawDisplayMode: Equatable {
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
}

/// Display resolution querying and mutation service implementation using CoreGraphics Display Mode APIs
public struct CoreGraphicsDisplayModeManager: DisplayModeManaging {
    public init() {}

    /// Filters raw modes to only those suitable for presentation to the user.
    ///
    /// Performs three steps:
    /// - Discards modes below 800x600 as unusable.
    /// - Deduplicates modes with identical logical resolution, favoring higher pixel density (HiDPI),
    ///   while ensuring the currently active mode is preserved even if it has fewer pixels.
    /// - Sorts ascending by width, then height.
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

        // Selection rules live in usableModes. Here we only map values from CoreGraphics.
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

        // Search matching CGDisplayMode (favoring exact HiDPI pixel dimensions)
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
