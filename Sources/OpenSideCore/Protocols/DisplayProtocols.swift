import Foundation
import CoreGraphics

/// 디스플레이 감지 인터페이스
/// 시스템에 연결된 디스플레이 목록을 조회하고 사이드카 연결 여부를 식별합니다.
public protocol DisplayDetecting: Sendable {
    /// 현재 활성화된 모든 디스플레이 목록을 반환합니다.
    func getActiveDisplays() -> [DisplayInfo]

    /// 연결된 사이드카 디스플레이가 있는 경우 반환합니다.
    func getSidecarDisplay() -> DisplayInfo?

    /// 메인 디스플레이를 반환합니다.
    func getMainDisplay() -> DisplayInfo?
}

/// 디스플레이 정렬 좌표 계산 인터페이스
/// 기준 화면(메인 맥북)과 대상 화면(아이패드)의 크기를 바탕으로 프리셋별 좌표를 계산합니다.
public protocol ArrangementCalculating: Sendable {
    /// 주어진 프리셋에 따른 대상 디스플레이의 목표 글로벌 원점 좌표 (x, y)를 계산합니다.
    /// - Parameters:
    ///   - mainBounds: 기준이 되는 주 디스플레이의 CGRect
    ///   - targetBounds: 이동할 대상 디스플레이(사이드카)의 CGRect
    ///   - preset: 적용하고자 하는 배치 프리셋
    /// - Returns: 계산된 목표 좌표 (x, y)
    func calculateOrigin(
        mainBounds: CGRect,
        targetBounds: CGRect,
        preset: DisplayArrangementPreset
    ) -> TargetDisplayOrigin
}

/// 디스플레이 설정 적용 인터페이스
/// CoreGraphics 트랜잭션을 통해 시스템 디스플레이 배치를 실제로 변경합니다.
public protocol DisplayConfiguring: Sendable {
    /// 지정된 디스플레이의 원점 좌표를 변경하여 영구적으로 적용합니다.
    /// - Parameters:
    ///   - displayID: 대상 디스플레이 ID
    ///   - origin: 설정할 목표 좌표
    /// - Returns: 설정 성공 여부 및 오류
    func configureDisplayOrigin(
        displayID: CGDirectDisplayID,
        origin: TargetDisplayOrigin
    ) -> Result<Void, DisplayConfigurationError>

    /// 디스플레이를 다른 디스플레이의 복제본으로 만들거나 그 상태를 해제합니다.
    /// - Parameters:
    ///   - displayID: 대상 디스플레이 ID
    ///   - masterID: 복제할 원본 디스플레이 ID. nil 이면 복제를 해제하고 확장으로 되돌립니다.
    ///   - persistence: 변경을 얼마나 오래 유지할지.
    func configureMirroring(
        displayID: CGDirectDisplayID,
        mirrorOf masterID: CGDirectDisplayID?,
        persistence: DisplayConfigurationPersistence
    ) -> Result<Void, DisplayConfigurationError>

    /// 해당 디스플레이가 지금 다른 디스플레이를 복제하고 있는지 알려줍니다.
    func isMirroring(displayID: CGDirectDisplayID) -> Bool
}

/// 이 앱이 만든 디스플레이가 무엇인지 알려줍니다.
///
/// 이 라이브러리를 쓰는 앱이 가상 디스플레이를 만들어 iPad 에 복제할 수 있습니다. 그 화면도 비내장이고
/// 복제에 얽혀 있어 판별 규칙에 그대로 걸립니다. 만든 쪽이 알려줘야 가릴 수 있습니다.
public protocol ManagedDisplayReporting: AnyObject, Sendable {
    /// 이 앱이 만들어 띄운 디스플레이. 없으면 nil.
    var managedDisplayID: CGDirectDisplayID? { get }
}

/// 캔버스를 쓰는 동안 화면 크기를 정하는 쪽. 쓰는 앱이 넣습니다. 안 넣으면 nil 입니다.
///
/// 캔버스는 고를 수 있는 크기 목록이 따로 있습니다. 그리고 크기를 바꾸는 방법도 다릅니다 —
/// 화면의 모드를 바꾸는 것이 아니라 캔버스를 그 크기로 다시 만듭니다. 가상 디스플레이는
/// 모드를 한 번이라도 바꾸면 놓아 주어도 프로세스가 끝날 때까지 화면이 남습니다.
/// 뷰모델과 같은 자리(메인 액터)에서만 불립니다. 목록과 선택이 화면과 붙어 있습니다.
@MainActor
public protocol CanvasSizing: AnyObject {
    /// 고를 수 있는 크기.
    var availableCanvasSizes: [DisplayResolutionMode] { get }

    /// 지금 쓰는 크기.
    var currentCanvasSize: DisplayResolutionMode? { get }

    /// 크기를 바꿉니다. 캔버스를 다시 만듭니다.
    func selectCanvasSize(_ mode: DisplayResolutionMode)
}

/// 디스플레이 설정 변경을 얼마나 오래 유지할지.
public enum DisplayConfigurationPersistence: Sendable {
    /// 로그아웃하면 원래대로 돌아갑니다.
    case session
    /// 다시 바꾸기 전까지 남습니다.
    case permanent
}

/// 디스플레이 구성 처리 중 발생 가능한 오류 타입
public enum DisplayConfigurationError: Error, LocalizedError, Equatable {
    case beginConfigurationFailed(code: Int32)
    case configureOriginFailed(code: Int32)
    case completeConfigurationFailed(code: Int32)
    case configureMirroringFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .beginConfigurationFailed(let code):
            return "디스플레이 구성 세션 시작 실패 (오류 코드: \(code))"
        case .configureOriginFailed(let code):
            return "디스플레이 좌표 변경 실패 (오류 코드: \(code))"
        case .completeConfigurationFailed(let code):
            return "디스플레이 구성 완료 커밋 실패 (오류 코드: \(code))"
        case .configureMirroringFailed(let code):
            return "디스플레이 복제 설정 실패 (오류 코드: \(code))"
        }
    }
}

/// 프리셋 저장소 인터페이스
/// 사용자가 최근에 선택한 정렬 프리셋 및 설정을 영속화합니다.
public protocol PresetManaging: Sendable {
    /// 마지막으로 적용된 프리셋을 저장합니다.
    func saveLastPreset(_ preset: DisplayArrangementPreset)

    /// 저장된 마지막 프리셋을 반환합니다.
    func loadLastPreset() -> DisplayArrangementPreset?

    /// 저장된 프리셋을 지웁니다. 사용자가 프리셋 대신 직접 끌어다 놓았을 때 호출합니다.
    func clearLastPreset()
}

/// 미니어처 캔버스 드래그 좌표를 글로벌 시스템 좌표로 변환하는 인터페이스
public protocol CoordinateTransforming: Sendable {
    /// 미니어처 뷰에서의 드래그 델타와 스케일을 바탕으로 새로운 글로벌 원점 좌표를 계산합니다.
    /// - Parameters:
    ///   - currentOrigin: 현재 대상 디스플레이의 글로벌 원점 (x, y)
    ///   - dragTranslation: 캔버스 상의 마우스 이동량 (dx, dy)
    ///   - scale: 캔버스의 실제 크기 대비 축소 배율
    /// - Returns: 계산된 새로운 글로벌 목표 좌표
    func transformDragToTargetOrigin(
        currentOrigin: CGPoint,
        dragTranslation: CGSize,
        scale: CGFloat
    ) -> TargetDisplayOrigin
}

/// 디스플레이 해상도 모드 목록 조회 및 변경 인터페이스
public protocol DisplayModeManaging: Sendable {
    /// 지정된 디스플레이가 지원하는 고유 해상도 모드 목록을 크기순으로 반환합니다.
    func getAvailableModes(displayID: CGDirectDisplayID) -> [DisplayResolutionMode]

    /// 지정된 디스플레이의 현재 적용된 해상도 모드를 반환합니다.
    func getCurrentMode(displayID: CGDirectDisplayID) -> DisplayResolutionMode?

    /// 지정된 디스플레이의 해상도를 변경합니다.
    /// - Parameter persistence: 변경을 얼마나 오래 유지할지. 기본값은 영구입니다.
    func setDisplayResolution(
        displayID: CGDirectDisplayID,
        mode: DisplayResolutionMode,
        persistence: DisplayConfigurationPersistence
    ) -> Result<Void, DisplayConfigurationError>

    /// 현재 해상도에서 HiDPI 전환이 가능한지 여부를 반환합니다.
    func canToggleHiDPI(displayID: CGDirectDisplayID) -> Bool

    /// 현재 해상도를 유지하면서 HiDPI 활성화 여부를 전환합니다.
    func toggleHiDPI(displayID: CGDirectDisplayID, enable: Bool) -> Result<Void, DisplayConfigurationError>
}

/// 사이드카 장비 검색 및 연결/해제 제어 인터페이스
public protocol SidecarConnecting: Sendable {
    /// 주변의 연결 가능한 사이드카 기기 목록을 반환합니다.
    func getAvailableDevices() -> [SidecarDeviceInfo]

    /// 지정된 사이드카 기기로 연결을 시작합니다.
    func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void)

    /// 지금 돌고 있는 세션의 지표를 읽습니다. 붙어 있지 않으면 nil.
    func currentSessionInfo() -> SidecarSessionInfo?

    /// 활성화된 사이드카 세션을 종료합니다.
    func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}
