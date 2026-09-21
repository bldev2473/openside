import AppKit
import OpenSideCore

// SwiftUI 의 App 을 쓰지 않습니다.
//
// 화면이 메뉴바뿐인 앱이라 App 에 담을 Scene 이 없는데, Scene 을 하나도 안 두면 컴파일이
// 막힙니다. 빈 Settings 화면을 두는 방법이 흔히 쓰이지만, 그 화면이 실행과 동시에 스스로
// 떠서 900x450 짜리 빈 창을 보여줍니다.
//
// 여기서는 AppKit 으로 직접 띄웁니다. 창을 만드는 쪽은 대리자뿐이고, 대리자는 메뉴바
// 항목만 세웁니다.
// 대리자와 AppKit 의 전역 상태는 메인 액터의 것이라 그 안에서 세웁니다.
MainActor.assumeIsolated {
    let delegate = OpenSideAppDelegate()
    let application = NSApplication.shared
    application.delegate = delegate
    // Dock 아이콘 없이 메뉴바에만 있습니다. Info.plist 의 LSUIElement 와 같은 뜻이며,
    // 번들 없이 실행될 때를 위해 여기서도 지정합니다.
    application.setActivationPolicy(.accessory)
    // 대리자는 앱이 도는 동안 살아 있어야 합니다. run() 이 돌아오지 않으므로 여기 둡니다.
    withExtendedLifetime(delegate) {
        application.run()
    }
}
