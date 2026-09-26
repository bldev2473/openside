import XCTest
import AppKit
@testable import OpenSideCore

/// Unit tests for menu bar right-click context menu builder and event handling.
final class StatusItemMenuTests: XCTestCase {

    /// Verifies menu item count, the four titles (About, Settings, Language, Quit OpenSide), and the language submenu.
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

        // 4 menu items + 1 separator = 5 items total
        XCTAssertEqual(menu.items.count, 5)

        // Title verification
        XCTAssertEqual(menu.items[0].title, "정보")
        XCTAssertEqual(menu.items[1].title, "설정")
        XCTAssertEqual(menu.items[2].title, "언어 설정")
        XCTAssertTrue(menu.items[3].isSeparatorItem)
        XCTAssertEqual(menu.items[4].title, "OpenSide 종료")

        // Keyboard shortcut verification
        XCTAssertEqual(menu.items[1].keyEquivalent, ",")
        XCTAssertEqual(menu.items[4].keyEquivalent, "q")

        // Verify language submenu (Korean, English, Japanese, Simplified Chinese)
        guard let languageSubmenu = menu.items[2].submenu else {
            XCTFail("Language settings submenu does not exist.")
            return
        }

        XCTAssertEqual(languageSubmenu.items.count, 4)
        XCTAssertEqual(languageSubmenu.items[0].title, "한국어")
        XCTAssertEqual(languageSubmenu.items[1].title, "English")
        XCTAssertEqual(languageSubmenu.items[2].title, "日本語")
        XCTAssertEqual(languageSubmenu.items[3].title, "简体中文")

        // Verify checkmark state for the selected language (Korean)
        XCTAssertEqual(languageSubmenu.items[0].state, .on)
        XCTAssertEqual(languageSubmenu.items[1].state, .off)
        XCTAssertEqual(languageSubmenu.items[2].state, .off)
        XCTAssertEqual(languageSubmenu.items[3].state, .off)
    }

    /// Verifies that target methods are invoked when selectors are triggered.
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

        // Trigger actions directly
        _ = dummyTarget.perform(menu.items[0].action)
        XCTAssertTrue(dummyTarget.aboutCalled)

        _ = dummyTarget.perform(menu.items[1].action)
        XCTAssertTrue(dummyTarget.settingsCalled)

        // Trigger submenu action
        guard let subItem = menu.items[2].submenu?.items.first else {
            XCTFail("Could not find submenu item.")
            return
        }
        _ = dummyTarget.perform(subItem.action, with: subItem)
        XCTAssertTrue(dummyTarget.languageCalled)

        _ = dummyTarget.perform(menu.items[4].action)
        XCTAssertTrue(dummyTarget.quitCalled)
    }
}

/// Dummy target object for testing action reception.
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
