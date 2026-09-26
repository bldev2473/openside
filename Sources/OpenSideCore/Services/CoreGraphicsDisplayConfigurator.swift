import Foundation
import CoreGraphics

/// Display reconfiguration implementation utilizing CoreGraphics Display Configuration C APIs
public struct CoreGraphicsDisplayConfigurator: DisplayConfiguring {
    public init() {}

    public func configureDisplayOrigin(
        displayID: CGDirectDisplayID,
        origin: TargetDisplayOrigin
    ) -> Result<Void, DisplayConfigurationError> {
        var configRef: CGDisplayConfigRef?

        // 1. Begin display reconfiguration transaction
        let beginResult = CGBeginDisplayConfiguration(&configRef)
        guard beginResult == .success, let config = configRef else {
            return .failure(.beginConfigurationFailed(code: beginResult.rawValue))
        }

        // 2. Set new display origin coordinates (x, y)
        let configureResult = CGConfigureDisplayOrigin(config, displayID, origin.x, origin.y)
        guard configureResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.configureOriginFailed(code: configureResult.rawValue))
        }

        // 3. Commit display configuration permanently
        let completeResult = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.completeConfigurationFailed(code: completeResult.rawValue))
        }

        return .success(())
    }
}

extension CoreGraphicsDisplayConfigurator {

    public func configureMirroring(
        displayID: CGDirectDisplayID,
        mirrorOf masterID: CGDirectDisplayID?,
        persistence: DisplayConfigurationPersistence = .session
    ) -> Result<Void, DisplayConfigurationError> {
        var configRef: CGDisplayConfigRef?

        let beginResult = CGBeginDisplayConfiguration(&configRef)
        guard beginResult == .success, let config = configRef else {
            return .failure(.beginConfigurationFailed(code: beginResult.rawValue))
        }

        // Passing kCGNullDirectDisplay as master dissolves mirroring and reverts to extended desktop.
        let master = masterID ?? kCGNullDirectDisplay
        let mirrorResult = CGConfigureDisplayMirrorOfDisplay(config, displayID, master)
        guard mirrorResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.configureMirroringFailed(code: mirrorResult.rawValue))
        }

        let scope: CGConfigureOption = persistence == .session ? .forSession : .permanently
        let completeResult = CGCompleteDisplayConfiguration(config, scope)
        guard completeResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.completeConfigurationFailed(code: completeResult.rawValue))
        }

        return .success(())
    }

    public func isMirroring(displayID: CGDirectDisplayID) -> Bool {
        CGDisplayMirrorsDisplay(displayID) != kCGNullDirectDisplay
    }
}
