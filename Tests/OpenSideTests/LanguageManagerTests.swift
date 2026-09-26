import XCTest
@testable import OpenSideCore

/// Unit tests for language models and language manager.
final class LanguageManagerTests: XCTestCase {

    /// Verifies autonyms for all 4 supported languages (Korean, English, Japanese, Simplified Chinese).
    func testAppLanguageCasesAndDisplayNames() {
        XCTAssertEqual(AppLanguage.allCases.count, 4)
        XCTAssertEqual(AppLanguage.korean.displayName, "한국어")
        XCTAssertEqual(AppLanguage.english.displayName, "English")
        XCTAssertEqual(AppLanguage.japanese.displayName, "日本語")
        XCTAssertEqual(AppLanguage.chinese.displayName, "简体中文")
    }

    /// Verifies language switching and persistence.
    func testLanguageManagerPersistence() throws {
        let testSuiteName = TestDefaults.name("LanguageSuite")
        let testDefaults = try TestDefaults.open(testSuiteName)
        defer { TestDefaults.remove(testSuiteName) }

        // Explicitly define Mac system language; otherwise test results depend on the runner's machine locale.
        let manager = UserDefaultsLanguageManager(
            userDefaults: testDefaults, preferredLanguages: ["ko-KR"]
        )
        XCTAssertEqual(manager.currentLanguage, .korean)

        // Switch to English
        manager.setLanguage(.english)
        XCTAssertEqual(manager.currentLanguage, .english)

        // Verify persistence restoration in a new instance
        let restoredManager = UserDefaultsLanguageManager(
            userDefaults: testDefaults, preferredLanguages: ["ko-KR"]
        )
        XCTAssertEqual(restoredManager.currentLanguage, .english)

        // Switch to Japanese
        restoredManager.setLanguage(.japanese)
        XCTAssertEqual(restoredManager.currentLanguage, .japanese)

        // Switch to Chinese
        restoredManager.setLanguage(.chinese)
        XCTAssertEqual(restoredManager.currentLanguage, .chinese)

    }

    /// Verifies localized UI string bundles (LocalizedUIStrings) for each language.
    func testLocalizedUIStrings() {
        // Korean
        let ko = AppLanguage.korean.strings
        XCTAssertEqual(ko.disconnect, "연결 해제")
        XCTAssertEqual(ko.rearrange, "재정렬")
        XCTAssertEqual(ko.settings, "설정")
        XCTAssertEqual(ko.languageSettings, "언어 설정")

        // English
        let en = AppLanguage.english.strings
        XCTAssertEqual(en.disconnect, "Disconnect")
        XCTAssertEqual(en.rearrange, "Rearrange")
        XCTAssertEqual(en.settings, "Settings")
        XCTAssertEqual(en.languageSettings, "Language")

        // Japanese
        let ja = AppLanguage.japanese.strings
        XCTAssertEqual(ja.disconnect, "接続解除")
        XCTAssertEqual(ja.rearrange, "再配置")
        XCTAssertEqual(ja.settings, "設定")
        XCTAssertEqual(ja.languageSettings, "言語設定")

        // Chinese
        let zh = AppLanguage.chinese.strings
        XCTAssertEqual(zh.disconnect, "断开连接")
        XCTAssertEqual(zh.rearrange, "重新排列")
        XCTAssertEqual(zh.settings, "设置")
        XCTAssertEqual(zh.languageSettings, "语言设置")
    }
}

/// Verifies initial language fallback when no prior selection exists.
///
/// Previously defaulted unconditionally to Korean. On English-configured Macs, this presented
/// an illegible interface on first launch, forcing users to locate language settings blindly.
final class DefaultLanguageTests: XCTestCase {

    /// Suites opened by this test suite; cleared completely upon teardown.
    private var opened: [String] = []

    override func tearDown() {
        opened.forEach(TestDefaults.remove)
        opened.removeAll()
        super.tearDown()
    }

    private func defaults(_ name: String) -> UserDefaults {
        opened.append(name)
        return (try? TestDefaults.open(name)) ?? UserDefaults(suiteName: name)!
    }

    /// Starts with system language if supported.
    func testSupportedSystemLanguageIsUsed() {
        for language in AppLanguage.allCases {
            let manager = UserDefaultsLanguageManager(
                userDefaults: defaults(TestDefaults.name("Default.\(language.rawValue)")),
                preferredLanguages: [language.rawValue]
            )
            XCTAssertEqual(manager.currentLanguage, language)
        }
    }

    /// Recognizes language codes with region subtags (e.g. macOS passes 'ko-KR' instead of 'ko').
    func testRegionTagIsIgnored() {
        let manager = UserDefaultsLanguageManager(
            userDefaults: defaults(TestDefaults.name("Default.Region")),
            preferredLanguages: ["ja-JP"]
        )
        XCTAssertEqual(manager.currentLanguage, .japanese)
    }

    /// Falls back to next preferred language if unsupported (macOS provides a prioritized list).
    func testNextPreferredLanguageIsTried() {
        let manager = UserDefaultsLanguageManager(
            userDefaults: defaults(TestDefaults.name("Default.List")),
            preferredLanguages: ["de-DE", "fr-FR", "zh-Hans-CN"]
        )
        XCTAssertEqual(manager.currentLanguage, .chinese)
    }

    /// Falls back to English if none match.
    func testEnglishIsTheLastResort() {
        let manager = UserDefaultsLanguageManager(
            userDefaults: defaults(TestDefaults.name("Default.None")),
            preferredLanguages: ["de-DE"]
        )
        XCTAssertEqual(manager.currentLanguage, .english)
    }

    /// Saved preference overrides system language.
    func testStoredChoiceWinsOverTheSystem() {
        let store = defaults(TestDefaults.name("Default.Stored"))
        UserDefaultsLanguageManager(userDefaults: store, preferredLanguages: ["en-US"])
            .setLanguage(.korean)

        let restored = UserDefaultsLanguageManager(
            userDefaults: store, preferredLanguages: ["en-US"]
        )
        XCTAssertEqual(restored.currentLanguage, .korean)
    }
}
