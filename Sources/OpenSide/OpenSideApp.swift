import SwiftUI
import AppKit

/// OpenSide 애플리케이션 수명 주기 및 메뉴바 관리 대리자
@MainActor
public final class OpenSideAppDelegate: NSObject, NSApplicationDelegate, MenuBarMenuHandling {
    private var statusItemManager: StatusItemManager?
    public let viewModel = DisplayManagerViewModel()

    public func applicationDidFinishLaunching(_ notification: Notification) {
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

/// OpenSide macOS 네이티브 메뉴바 애플리케이션 엔트리포인트
@main
struct OpenSideApp: App {
    @NSApplicationDelegateAdaptor(OpenSideAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
