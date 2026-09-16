import SwiftUI

/// 환경설정 창 뷰
///
/// 쓰는 앱이 자체 섹션을 덧붙일 수 있도록 `extraSections` 를 받습니다.
/// 이 앱에서는 비어 있습니다.
public struct SettingsView<Extra: View>: View {
    @ObservedObject public var languageManager: UserDefaultsLanguageManager
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    private let extraSections: Extra

    public init(
        languageManager: UserDefaultsLanguageManager = .shared,
        @ViewBuilder extraSections: () -> Extra
    ) {
        self.languageManager = languageManager
        self.extraSections = extraSections()
    }

    public var body: some View {
        let strings = languageManager.currentLanguage.strings

        Form {
            Section(strings.generalSection) {
                Toggle(strings.launchAtLogin, isOn: $launchAtLogin)
            }

            Section(strings.languagePicker) {
                Picker(strings.languagePicker, selection: Binding(
                    get: { languageManager.currentLanguage },
                    set: { newLanguage in languageManager.setLanguage(newLanguage) }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            extraSections
        }
        .formStyle(.grouped)
        // 섹션이 늘어날 수 있으므로 높이는 고정하지 않습니다.
        .frame(width: 360)
        .frame(minHeight: 240)
    }
}

extension SettingsView where Extra == EmptyView {
    /// 추가 섹션이 없는 기본 설정 창
    public init(languageManager: UserDefaultsLanguageManager = .shared) {
        self.init(languageManager: languageManager) { EmptyView() }
    }
}
