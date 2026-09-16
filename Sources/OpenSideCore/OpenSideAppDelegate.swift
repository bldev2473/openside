import SwiftUI
import AppKit

/// OpenSide 애플리케이션 수명 주기 및 메뉴바 관리 대리자
@MainActor
open class OpenSideAppDelegate: NSObject, NSApplicationDelegate, MenuBarMenuHandling {
    private var statusItemManager: StatusItemManager?
    public private(set) lazy var viewModel: DisplayManagerViewModel = makeViewModel()

    /// 뷰모델 생성 지점. 이 라이브러리를 쓰는 앱이 배터리 조회 같은 구현체를 넣으려면 재정의합니다.
    open func makeViewModel() -> DisplayManagerViewModel {
        DisplayManagerViewModel()
    }

    open func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemManager = StatusItemManager(viewModel: viewModel, menuHandler: self)
    }

    /// '정보' 메뉴 선택 처리: 표준 About 패널 노출
    public func didSelectAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    /// '설정' 메뉴 선택 처리: 설정 팝업 창 화면 노출
    public func didSelectSettings() {
        SettingsWindowController.shared.showSettingsWindow()
    }

    /// '언어 설정' 메뉴 선택 처리
    public func didSelectLanguage(_ language: AppLanguage) {
        UserDefaultsLanguageManager.shared.setLanguage(language)
    }

    /// 'OpenSide 종료' 메뉴 선택 처리
    public func didSelectTerminate() {
        NSApp.terminate(nil)
    }
}
