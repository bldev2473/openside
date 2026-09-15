import Foundation

/// 메뉴바 우클릭 컨텍스트 메뉴 액션 위임 인터페이스
@MainActor
public protocol MenuBarMenuHandling: AnyObject, Sendable {
    /// '정보' 메뉴 선택 시 호출됩니다.
    func didSelectAbout()

    /// '설정' 메뉴 선택 시 호출됩니다.
    func didSelectSettings()

    /// 특정 언어 선택 시 호출됩니다.
    func didSelectLanguage(_ language: AppLanguage)

    /// 'OpenSide 종료' 메뉴 선택 시 호출됩니다.
    func didSelectTerminate()
}
