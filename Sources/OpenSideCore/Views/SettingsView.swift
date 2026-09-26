import SwiftUI

/// Settings window view.
///
/// Accepts `extraSections` so consumer apps can append custom sections.
/// Kept empty in this app.
public struct SettingsView<Extra: View>: View {
    @ObservedObject public var languageManager: UserDefaultsLanguageManager
    /// Pass view model to display session metrics; omitting omits the section.
    @ObservedObject public var viewModel: DisplayManagerViewModel
    /// Login item registration state, read directly from system rather than cached storage.
    @StateObject private var loginItem: LoginItemToggle

    private let extraSections: Extra

    // LoginItemToggle is a MainActor, so instantiate here. Passing as default argument evaluates
    // in non-isolated context regardless of init isolation, causing compilation failure.
    @MainActor
    public init(
        viewModel: DisplayManagerViewModel,
        languageManager: UserDefaultsLanguageManager = .shared,
        loginItem: LoginItemToggle? = nil,
        @ViewBuilder extraSections: () -> Extra
    ) {
        self.viewModel = viewModel
        self.languageManager = languageManager
        self._loginItem = StateObject(wrappedValue: loginItem ?? LoginItemToggle())
        self.extraSections = extraSections()
    }

    public var body: some View {
        let strings = languageManager.currentLanguage.strings

        Form {
            Section(strings.generalSection) {
                Toggle(strings.launchAtLogin, isOn: Binding(
                    get: { loginItem.isOn },
                    set: { loginItem.set($0) }
                ))

                // If registration is denied, display the reason directly rather than leaving toggle enabled.
                if let failure = loginItem.failure {
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if loginItem.needsApproval {
                    // macOS accepted registration but requires user approval. Not an error.
                    Text(strings.launchAtLoginNeedsApproval)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Visible only when connected; no values to show without an active session.
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
        .onAppear { loginItem.refresh() }
        .formStyle(.grouped)
        // Height is not fixed as sections may dynamically expand.
        .frame(width: 360)
        .frame(minHeight: 240)
    }
}

extension SettingsView where Extra == EmptyView {
    /// Default settings window without additional sections.
    public init(
        viewModel: DisplayManagerViewModel,
        languageManager: UserDefaultsLanguageManager = .shared
    ) {
        self.init(viewModel: viewModel, languageManager: languageManager) { EmptyView() }
    }
}
