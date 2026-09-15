import Foundation
import CoreGraphics

/// CoreGraphics Display Configuration C API를 활용한 디스플레이 재배치 구성기 구현체
public struct CoreGraphicsDisplayConfigurator: DisplayConfiguring {
    public init() {}

    public func configureDisplayOrigin(
        displayID: CGDirectDisplayID,
        origin: TargetDisplayOrigin
    ) -> Result<Void, DisplayConfigurationError> {
        var configRef: CGDisplayConfigRef?

        // 1. 디스플레이 재구성 세션 시작
        let beginResult = CGBeginDisplayConfiguration(&configRef)
        guard beginResult == .success, let config = configRef else {
            return .failure(.beginConfigurationFailed(code: beginResult.rawValue))
        }

        // 2. 디스플레이 원점 좌표(x, y) 재설정
        let configureResult = CGConfigureDisplayOrigin(config, displayID, origin.x, origin.y)
        guard configureResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.configureOriginFailed(code: configureResult.rawValue))
        }

        // 3. 영구 적용 모드로 디스플레이 구성 커밋
        let completeResult = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeResult == .success else {
            CGCancelDisplayConfiguration(config)
            return .failure(.completeConfigurationFailed(code: completeResult.rawValue))
        }

        return .success(())
    }
}
