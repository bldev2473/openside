import Foundation

/// Supported languages in OpenSide
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"

    public var id: String { rawValue }

    /// Picks the first supported language from the list preferred by the Mac.
    ///
    /// macOS provides tags with region and script, like ko-KR or zh-Hans-CN, rather than just ko.
    /// We match using only the prefix. If none match, default to English.
    public static func matching(_ preferredLanguages: [String]) -> AppLanguage {
        for tag in preferredLanguages {
            let code = tag.split(separator: "-").first.map(String.init) ?? tag
            if let language = AppLanguage(rawValue: code) { return language }
        }
        return .english
    }

    /// Native language names (autonyms) displayed in menus and UI
    public var displayName: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .chinese:
            return "简体中文"
        }
    }
}
