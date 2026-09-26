import Foundation

/// Delegate interface for menu bar context menu actions
@MainActor
public protocol MenuBarMenuHandling: AnyObject, Sendable {
    /// Invoked when 'About' is selected
    func didSelectAbout()

    /// Invoked when 'Settings' is selected
    func didSelectSettings()

    /// Invoked when a specific language is selected
    func didSelectLanguage(_ language: AppLanguage)

    /// Invoked when 'Quit OpenSide' is selected
    func didSelectTerminate()
}
