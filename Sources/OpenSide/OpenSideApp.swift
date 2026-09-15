import SwiftUI
import OpenSideCore

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
