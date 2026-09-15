import XCTest
import AppKit
@testable import OpenSide

/// 메뉴바 우클릭 컨텍스트 메뉴 빌더 및 이벤트 핸들링 단위 테스트
final class StatusItemMenuTests: XCTestCase {

    /// 메뉴 항목 개수 및 정확한 4개 타이틀(정보, 설정, 언어 설정, OpenSide 종료) 및 언어 서브메뉴 검증
    @MainActor
    func testStatusItemMenuStructureAndTitles() {
        let builder = StatusItemMenuBuilder()
        let dummyTarget = DummyMenuTarget()

        let menu = builder.buildMenu(
            target: dummyTarget,
            currentLanguage: .korean,
            aboutAction: #selector(DummyMenuTarget.about),
            settingsAction: #selector(DummyMenuTarget.settings),
            languageAction: #selector(DummyMenuTarget.language(_:)),
            quitAction: #selector(DummyMenuTarget.quit)
        )

        // 4개 메뉴 항목 + 구분선 1개 = 총 5개
        XCTAssertEqual(menu.items.count, 5)

        // 타이틀 검증
        XCTAssertEqual(menu.items[0].title, "정보")
        XCTAssertEqual(menu.items[1].title, "설정")
        XCTAssertEqual(menu.items[2].title, "언어 설정")
        XCTAssertTrue(menu.items[3].isSeparatorItem)
        XCTAssertEqual(menu.items[4].title, "OpenSide 종료")

        // 단축키 검증
        XCTAssertEqual(menu.items[1].keyEquivalent, ",")
        XCTAssertEqual(menu.items[4].keyEquivalent, "q")

        // 언어 서브메뉴(한국어, 영어, 일본어, 중국어) 검증
        guard let languageSubmenu = menu.items[2].submenu else {
            XCTFail("언어 설정 서브메뉴가 존재하지 않습니다.")
            return
        }

        XCTAssertEqual(languageSubmenu.items.count, 4)
        XCTAssertEqual(languageSubmenu.items[0].title, "한국어")
        XCTAssertEqual(languageSubmenu.items[1].title, "English")
        XCTAssertEqual(languageSubmenu.items[2].title, "日本語")
        XCTAssertEqual(languageSubmenu.items[3].title, "简体中文")

        // 선택된 언어(한국어) 체크마크 상태 검증
        XCTAssertEqual(languageSubmenu.items[0].state, .on)
        XCTAssertEqual(languageSubmenu.items[1].state, .off)
        XCTAssertEqual(languageSubmenu.items[2].state, .off)
        XCTAssertEqual(languageSubmenu.items[3].state, .off)
    }

    /// 셀렉터 발화 시 타깃 메서드 정상 호출 여부 검증
    @MainActor
    func testStatusItemMenuActionRouting() {
        let builder = StatusItemMenuBuilder()
        let dummyTarget = DummyMenuTarget()

        let menu = builder.buildMenu(
            target: dummyTarget,
            currentLanguage: .english,
            aboutAction: #selector(DummyMenuTarget.about),
            settingsAction: #selector(DummyMenuTarget.settings),
            languageAction: #selector(DummyMenuTarget.language(_:)),
            quitAction: #selector(DummyMenuTarget.quit)
        )

        // 액션 직접 트리거
        _ = dummyTarget.perform(menu.items[0].action)
        XCTAssertTrue(dummyTarget.aboutCalled)

        _ = dummyTarget.perform(menu.items[1].action)
        XCTAssertTrue(dummyTarget.settingsCalled)

        // 서브메뉴 액션 트리거
        guard let subItem = menu.items[2].submenu?.items.first else {
            XCTFail("서브메뉴 항목을 찾을 수 없습니다.")
            return
        }
        _ = dummyTarget.perform(subItem.action, with: subItem)
        XCTAssertTrue(dummyTarget.languageCalled)

        _ = dummyTarget.perform(menu.items[4].action)
        XCTAssertTrue(dummyTarget.quitCalled)
    }
}

/// 테스트용 더미 액션 수신 타깃 객체
private final class DummyMenuTarget: NSObject {
    var aboutCalled = false
    var settingsCalled = false
    var languageCalled = false
    var quitCalled = false

    @objc func about() { aboutCalled = true }
    @objc func settings() { settingsCalled = true }
    @objc func language(_ sender: Any?) { languageCalled = true }
    @objc func quit() { quitCalled = true }
}
