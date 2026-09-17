import AppKit
import SwiftUI

/// 환경설정 창 생명주기 및 화면 표시를 관리하는 윈도우 컨트롤러
@MainActor
public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            // 쓰는 앱이 섹션을 더하면 내용이 길어질 수 있으므로 크기를 바꿀 수 있게 둡니다.
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "설정"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 주어진 뷰를 담아 설정 창을 화면 중앙에 표시합니다.
    ///
    /// 창을 열 때마다 내용을 새로 호스팅합니다. 쓰는 앱이 넘기는 뷰가 그때그때 달라질 수
    /// 있고, 세션 기록처럼 열 때 최신 상태를 읽어야 하는 내용도 있기 때문입니다.
    public func showSettingsWindow<Content: View>(content: Content) {
        window?.title = UserDefaultsLanguageManager.shared.currentLanguage.strings.settingsTitle
        window?.contentView = NSHostingView(rootView: content)
        window?.setContentSize(NSHostingView(rootView: content).fittingSize)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
