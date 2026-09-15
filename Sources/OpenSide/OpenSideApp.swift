import SwiftUI

/// OpenSide macOS 네이티브 메뉴바 애플리케이션 엔트리포인트
@main
struct OpenSideApp: App {
    @StateObject private var viewModel = DisplayManagerViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopupView(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.isSidecarConnected ? "display.2" : "display")
        }
        .menuBarExtraStyle(.window)
    }
}
