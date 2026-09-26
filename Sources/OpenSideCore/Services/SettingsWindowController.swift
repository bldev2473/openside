import AppKit
import SwiftUI

/// Window controller managing settings window lifecycle and presentation
@MainActor
public final class SettingsWindowController: NSWindowController {
    public static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            // Allows resizing as consuming apps may append custom sections.
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = UserDefaultsLanguageManager.shared.currentLanguage.strings.settingsTitle
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Displays the settings window centered on screen hosting the given view.
    ///
    /// Re-hosts content on every presentation because consuming apps can supply dynamic views,
    /// and views like session logs need to read the latest state when opened.
    public func showSettingsWindow<Content: View>(content: Content) {
        window?.title = UserDefaultsLanguageManager.shared.currentLanguage.strings.settingsTitle
        window?.contentView = NSHostingView(rootView: content)
        window?.setContentSize(NSHostingView(rootView: content).fittingSize)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
