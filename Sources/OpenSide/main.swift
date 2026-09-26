import AppKit
import OpenSideCore

// Do not use SwiftUI's App.
//
// Because this app lives only in the menu bar, there is no Scene to host in App,
// and having no Scene at all fails compilation. Keeping an empty Settings scene
// is a common workaround, but that window opens itself on launch and shows a blank
// 900x450 window.
//
// Here, we launch directly via AppKit. Only the delegate creates anything, and the
// delegate only creates the menu bar item.
// The delegate and AppKit's global state belong to the main actor, so we initialize them inside it.
MainActor.assumeIsolated {
    let delegate = OpenSideAppDelegate()
    let application = NSApplication.shared
    application.delegate = delegate
    // Lives only in the menu bar with no Dock icon. Equivalent to LSUIElement in Info.plist,
    // and specified here as well for when running without a bundle.
    application.setActivationPolicy(.accessory)
    // The delegate must stay alive while the app runs. run() never returns, so extended lifetime is used here.
    withExtendedLifetime(delegate) {
        application.run()
    }
}
