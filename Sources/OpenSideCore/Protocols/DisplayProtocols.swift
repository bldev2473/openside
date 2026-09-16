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
}

/// 디스플레이 구성 처리 중 발생 가능한 오류 타입
public enum DisplayConfigurationError: Error, LocalizedError, Equatable {
    case beginConfigurationFailed(code: Int32)
    case configureOriginFailed(code: Int32)
    case completeConfigurationFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .beginConfigurationFailed(let code):
            return "디스플레이 구성 세션 시작 실패 (오류 코드: \(code))"
        case .configureOriginFailed(let code):
            return "디스플레이 좌표 변경 실패 (오류 코드: \(code))"
        case .completeConfigurationFailed(let code):
            return "디스플레이 구성 완료 커밋 실패 (오류 코드: \(code))"
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

    /// 지정된 디스플레이의 해상도를 변경하여 영구적으로 적용합니다.
    func setDisplayResolution(
        displayID: CGDirectDisplayID,
        mode: DisplayResolutionMode
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

    /// 활성화된 사이드카 세션을 종료합니다.
    func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void)
}
