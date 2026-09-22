import XCTest
@testable import OpenSideCore

/// 언어 모델 및 언어 관리자 단위 테스트
final class LanguageManagerTests: XCTestCase {

    /// 4개 지원 언어(한국어, English, 日本語, 简体中文) 고유 명칭(Autonyms) 검증
    func testAppLanguageCasesAndDisplayNames() {
        XCTAssertEqual(AppLanguage.allCases.count, 4)
        XCTAssertEqual(AppLanguage.korean.displayName, "한국어")
        XCTAssertEqual(AppLanguage.english.displayName, "English")
        XCTAssertEqual(AppLanguage.japanese.displayName, "日本語")
        XCTAssertEqual(AppLanguage.chinese.displayName, "简体中文")
    }

    /// 언어 변경 및 설정값 저장/조회 검증
    func testLanguageManagerPersistence() throws {
        let testSuiteName = TestDefaults.name("LanguageSuite")
        let testDefaults = try TestDefaults.open(testSuiteName)
        defer { TestDefaults.remove(testSuiteName) }

        // 맥의 언어를 명시해 둔다. 빼면 이 시험이 돌리는 사람의 맥 설정에 따라 달라진다.
        let manager = UserDefaultsLanguageManager(
            userDefaults: testDefaults, preferredLanguages: ["ko-KR"]
        )
        XCTAssertEqual(manager.currentLanguage, .korean)

        // 영어로 변경
        manager.setLanguage(.english)
        XCTAssertEqual(manager.currentLanguage, .english)

        // 새로운 인스턴스에서 영속화 값 복원 검증
        let restoredManager = UserDefaultsLanguageManager(
            userDefaults: testDefaults, preferredLanguages: ["ko-KR"]
        )
        XCTAssertEqual(restoredManager.currentLanguage, .english)

        // 일본어로 변경
        restoredManager.setLanguage(.japanese)
        XCTAssertEqual(restoredManager.currentLanguage, .japanese)

        // 중국어로 변경
        restoredManager.setLanguage(.chinese)
        XCTAssertEqual(restoredManager.currentLanguage, .chinese)

    }

    /// 각 언어별 UI 텍스트 번들(LocalizedUIStrings) 정상 매핑 검증
    func testLocalizedUIStrings() {
        // 한국어
        let ko = AppLanguage.korean.strings
        XCTAssertEqual(ko.disconnect, "연결 해제")
        XCTAssertEqual(ko.rearrange, "재정렬")
        XCTAssertEqual(ko.settings, "설정")
        XCTAssertEqual(ko.languageSettings, "언어 설정")

        // 영어
        let en = AppLanguage.english.strings
        XCTAssertEqual(en.disconnect, "Disconnect")
        XCTAssertEqual(en.rearrange, "Rearrange")
        XCTAssertEqual(en.settings, "Settings")
        XCTAssertEqual(en.languageSettings, "Language")

        // 일본어
        let ja = AppLanguage.japanese.strings
        XCTAssertEqual(ja.disconnect, "接続解除")
        XCTAssertEqual(ja.rearrange, "再配置")
        XCTAssertEqual(ja.settings, "設定")
        XCTAssertEqual(ja.languageSettings, "言語設定")

        // 중국어
        let zh = AppLanguage.chinese.strings
        XCTAssertEqual(zh.disconnect, "断开连接")
        XCTAssertEqual(zh.rearrange, "重新排列")
        XCTAssertEqual(zh.settings, "设置")
        XCTAssertEqual(zh.languageSettings, "语言设置")
    }
}

/// 고른 적이 없을 때 어느 언어로 시작하는지 본다.
///
/// 예전에는 무조건 한국어로 시작했다. 영어를 쓰는 맥에서 처음 켜면 읽지 못하는 메뉴가
/// 뜨고, 그 메뉴 안에서 언어를 찾아 바꿔야 했다.
final class DefaultLanguageTests: XCTestCase {

    /// 이 시험이 연 저장소들. 끝날 때 값과 파일을 모두 치웁니다.
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

    /// 맥의 언어가 우리가 지원하는 것이면 그것으로 시작한다.
    func testSupportedSystemLanguageIsUsed() {
        for language in AppLanguage.allCases {
            let manager = UserDefaultsLanguageManager(
                userDefaults: defaults(TestDefaults.name("Default.\(language.rawValue)")),
                preferredLanguages: [language.rawValue]
            )
            XCTAssertEqual(manager.currentLanguage, language)
        }
    }

    /// 지역 표기가 붙어도 알아본다. macOS 는 ko 가 아니라 ko-KR 로 준다.
    func testRegionTagIsIgnored() {
        let manager = UserDefaultsLanguageManager(
            userDefaults: defaults(TestDefaults.name("Default.Region")),
            preferredLanguages: ["ja-JP"]
        )
        XCTAssertEqual(manager.currentLanguage, .japanese)
    }

    /// 지원하지 않는 언어면 그다음 선호 언어를 본다. 맥은 목록으로 준다.
    func testNextPreferredLanguageIsTried() {
        let manager = UserDefaultsLanguageManager(
            userDefaults: defaults(TestDefaults.name("Default.List")),
            preferredLanguages: ["de-DE", "fr-FR", "zh-Hans-CN"]
        )
        XCTAssertEqual(manager.currentLanguage, .chinese)
    }

    /// 하나도 못 맞추면 영어로 둔다. 한국어보다 읽을 수 있는 사람이 많다.
    func testEnglishIsTheLastResort() {
        let manager = UserDefaultsLanguageManager(
            userDefaults: defaults(TestDefaults.name("Default.None")),
            preferredLanguages: ["de-DE"]
        )
        XCTAssertEqual(manager.currentLanguage, .english)
    }

    /// 저장된 값이 맥의 언어를 이긴다. 사용자가 고른 것이 먼저다.
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
