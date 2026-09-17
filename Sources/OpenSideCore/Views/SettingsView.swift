import SwiftUI

/// 환경설정 창 뷰
///
/// 쓰는 앱이 자체 섹션을 덧붙일 수 있도록 `extraSections` 를 받습니다.
/// 이 앱에서는 비어 있습니다.
public struct SettingsView<Extra: View>: View {
    @ObservedObject public var languageManager: UserDefaultsLanguageManager
    /// 세션 지표를 보여주려면 넘깁니다. 없으면 그 섹션이 사라집니다.
    @ObservedObject public var viewModel: DisplayManagerViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    private let extraSections: Extra

    public init(
        viewModel: DisplayManagerViewModel,
        languageManager: UserDefaultsLanguageManager = .shared,
        @ViewBuilder extraSections: () -> Extra
    ) {
        self.viewModel = viewModel
        self.languageManager = languageManager
        self.extraSections = extraSections()
    }

    public var body: some View {
        let strings = languageManager.currentLanguage.strings

        Form {
            Section(strings.generalSection) {
                Toggle(strings.launchAtLogin, isOn: $launchAtLogin)
            }

            // 붙어 있을 때만 나옵니다. 세션이 없으면 보여줄 값이 없습니다.
            if let session = viewModel.sessionInfo {
                Section(strings.sessionInfoSection) {
                    LabeledContent(strings.sessionFramerate, value: "\(session.framerate) Hz")
                    LabeledContent(strings.sessionBitrate, value: session.bitrateText)
                    LabeledContent(strings.sessionSize, value: session.sizeText)
                    LabeledContent(strings.sessionHDR, value: session.isHDR ? strings.onWord : strings.offWord)
                }
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
    public init(
        viewModel: DisplayManagerViewModel,
        languageManager: UserDefaultsLanguageManager = .shared
    ) {
        self.init(viewModel: viewModel, languageManager: languageManager) { EmptyView() }
    }
}
