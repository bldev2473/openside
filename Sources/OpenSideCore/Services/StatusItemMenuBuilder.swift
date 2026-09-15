import AppKit

/// 메뉴바 아이콘 우클릭 시 표시될 NSMenu를 구성하는 빌더
public struct StatusItemMenuBuilder: Sendable {
    public init() {}

    /// 제공된 핸들러와 셀렉터를 바인딩하여 우클릭 컨텍스트 메뉴를 생성합니다.
    /// - Parameters:
    ///   - target: 메뉴 액션을 수신할 타깃 객체
    ///   - currentLanguage: 현재 선택된 언어
    ///   - aboutAction: '정보' 선택 시 호출될 셀렉터
    ///   - settingsAction: '설정' 선택 시 호출될 셀렉터
    ///   - languageAction: 서브메뉴 언어 선택 시 호출될 셀렉터
    ///   - quitAction: 'OpenSide 종료' 선택 시 호출될 셀렉터
    /// - Returns: 구성된 NSMenu 인스턴스
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

        // 1. 정보
        let aboutItem = NSMenuItem(title: strings.about, action: aboutAction, keyEquivalent: "")
        aboutItem.target = target
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)

        // 2. 설정
        let settingsItem = NSMenuItem(title: strings.settings, action: settingsAction, keyEquivalent: ",")
        settingsItem.target = target
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)

        // 3. 언어 설정 (우측 서브메뉴: 한국어, 영어, 일본어, 중국어)
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

        // 구분선
        menu.addItem(NSMenuItem.separator())

        // 4. OpenSide 종료
        let quitItem = NSMenuItem(title: strings.quitOpenSide, action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        return menu
    }
}
