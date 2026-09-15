import SwiftUI

/// 환경설정 창 뷰
public struct SettingsView: View {
    @ObservedObject public var languageManager: UserDefaultsLanguageManager
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    public init(languageManager: UserDefaultsLanguageManager = .shared) {
        self.languageManager = languageManager
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
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 240)
    }
}
