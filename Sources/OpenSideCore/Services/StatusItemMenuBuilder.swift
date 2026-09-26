import AppKit

/// Builder constructing the NSMenu presented on right-clicking the status item
public struct StatusItemMenuBuilder: Sendable {
    public init() {}

    /// Builds the right-click context menu bound to provided handlers and selectors.
    /// - Parameters:
    ///   - target: Target object receiving menu actions
    ///   - currentLanguage: Currently selected language
    ///   - aboutAction: Selector invoked on selecting 'About'
    ///   - settingsAction: Selector invoked on selecting 'Settings'
    ///   - languageAction: Selector invoked on selecting language submenu items
    ///   - quitAction: Selector invoked on selecting 'Quit OpenSide'
    /// - Returns: Configured NSMenu instance
    @MainActor
    public func buildMenu(
        target: AnyObject,
        currentLanguage: AppLanguage = .korean,
        aboutAction: Selector,
        settingsAction: Selector,
        languageAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let strings = currentLanguage.strings
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 1. About
        let aboutItem = NSMenuItem(title: strings.about, action: aboutAction, keyEquivalent: "")
        aboutItem.target = target
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)

        // 2. Settings
        let settingsItem = NSMenuItem(title: strings.settings, action: settingsAction, keyEquivalent: ",")
        settingsItem.target = target
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)

        // 3. Language settings (Submenu: Korean, English, Japanese, Chinese)
        let languageItem = NSMenuItem(title: strings.languageSettings, action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu(title: strings.languageSettings)
        languageSubmenu.autoenablesItems = false

        for language in AppLanguage.allCases {
            let subItem = NSMenuItem(
                title: language.displayName,
                action: languageAction,
                keyEquivalent: ""
            )
            subItem.target = target
            subItem.representedObject = language
            subItem.state = (language == currentLanguage) ? .on : .off
            subItem.isEnabled = true
            languageSubmenu.addItem(subItem)
        }

        languageItem.submenu = languageSubmenu
        menu.addItem(languageItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // 4. Quit OpenSide
        let quitItem = NSMenuItem(title: strings.quitOpenSide, action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        return menu
    }
}
