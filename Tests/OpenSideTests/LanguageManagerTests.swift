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
    func testLanguageManagerPersistence() {
        let testSuiteName = "OpenSideTests.LanguageSuite"
        guard let testDefaults = UserDefaults(suiteName: testSuiteName) else {
            XCTFail("테스트용 UserDefaults 초기화 실패")
            return
        }
        testDefaults.removePersistentDomain(forName: testSuiteName)

        let manager = UserDefaultsLanguageManager(userDefaults: testDefaults)

        // 기본값: 한국어
        XCTAssertEqual(manager.currentLanguage, .korean)

        // 영어로 변경
        manager.setLanguage(.english)
        XCTAssertEqual(manager.currentLanguage, .english)

        // 새로운 인스턴스에서 영속화 값 복원 검증
        let restoredManager = UserDefaultsLanguageManager(userDefaults: testDefaults)
        XCTAssertEqual(restoredManager.currentLanguage, .english)

        // 일본어로 변경
        restoredManager.setLanguage(.japanese)
        XCTAssertEqual(restoredManager.currentLanguage, .japanese)

        // 중국어로 변경
        restoredManager.setLanguage(.chinese)
        XCTAssertEqual(restoredManager.currentLanguage, .chinese)

        testDefaults.removePersistentDomain(forName: testSuiteName)
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
