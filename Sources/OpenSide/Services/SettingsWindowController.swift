import AppKit
import SwiftUI

/// 환경설정 창 생명주기 및 화면 표시를 관리하는 윈도우 컨트롤러
@MainActor
public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "설정"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 설정 창을 화면 중앙에 활성화하여 최상단에 표시합니다.
    public func showSettingsWindow() {
        window?.title = UserDefaultsLanguageManager.shared.currentLanguage.strings.settingsTitle
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
