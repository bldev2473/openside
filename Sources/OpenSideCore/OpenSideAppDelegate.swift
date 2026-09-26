import SwiftUI
import AppKit

/// OpenSide application lifecycle and menu bar delegate
@MainActor
open class OpenSideAppDelegate: NSObject, NSApplicationDelegate, MenuBarMenuHandling {
    private var statusItemManager: StatusItemManager?
    public private(set) lazy var viewModel: DisplayManagerViewModel = makeViewModel()

    /// ViewModel factory method. Subclass this if an app using this library needs to inject implementations like battery fetching.
    open func makeViewModel() -> DisplayManagerViewModel {
        DisplayManagerViewModel()
    }

    open func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemManager = StatusItemManager(viewModel: viewModel, menuHandler: self)
    }

    /// Handles 'About' menu selection: presents the standard About panel
    public func didSelectAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    /// The view hosted inside the settings window. Subclass this if an app needs to add custom sections.
    open func makeSettingsView() -> AnyView {
        AnyView(SettingsView(viewModel: viewModel))
    }

    /// Handles 'Settings' menu selection: presents the settings window
    public func didSelectSettings() {
        SettingsWindowController.shared.showSettingsWindow(content: makeSettingsView())
    }

    /// Handles 'Language' menu selection
    public func didSelectLanguage(_ language: AppLanguage) {
        UserDefaultsLanguageManager.shared.setLanguage(language)
    }

    /// Handles 'Quit OpenSide' menu selection
    public func didSelectTerminate() {
        NSApp.terminate(nil)
    }
}
