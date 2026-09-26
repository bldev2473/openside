import Foundation
import Combine

/// Application language management interface
public protocol LanguageManaging: AnyObject, Sendable {
    /// Currently selected language
    var currentLanguage: AppLanguage { get }

    /// Sets and persists language
    func setLanguage(_ language: AppLanguage)
}

/// UserDefaults-backed language preference manager implementation
public final class UserDefaultsLanguageManager: ObservableObject, LanguageManaging, @unchecked Sendable {
    public static let shared = UserDefaultsLanguageManager()

    private let userDefaults: UserDefaults
    private let storageKey = "OpenSide.SelectedLanguage"

    @Published public private(set) var currentLanguage: AppLanguage

    /// - Parameter preferredLanguages: List of languages preferred by the Mac. Checked only when no explicit choice has been saved.
    public init(
        userDefaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.userDefaults = userDefaults
        if let savedCode = userDefaults.string(forKey: storageKey),
           let language = AppLanguage(rawValue: savedCode) {
            self.currentLanguage = language
        } else {
            // When no choice is saved, match against system preferences. Hardcoding Korean
            // causes English Mac systems to show unreadable menus on first launch.
            self.currentLanguage = AppLanguage.matching(preferredLanguages)
        }
    }

    /// Sets language and saves preference
    public func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        userDefaults.set(language.rawValue, forKey: storageKey)
    }
}
