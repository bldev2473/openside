import SwiftUI

/// Grid view containing one-click display arrangement preset buttons.
public struct PresetButtonGrid: View {
    public let isEnabled: Bool
    public let selectedPreset: DisplayArrangementPreset?
    @ObservedObject public var languageManager: UserDefaultsLanguageManager
    public let onSelect: (DisplayArrangementPreset) -> Void

    public init(
        isEnabled: Bool,
        selectedPreset: DisplayArrangementPreset?,
        languageManager: UserDefaultsLanguageManager = .shared,
        onSelect: @escaping (DisplayArrangementPreset) -> Void
    ) {
        self.isEnabled = isEnabled
        self.selectedPreset = selectedPreset
        self.languageManager = languageManager
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Top
            HStack {
                presetButton(preset: .topCenter, icon: "arrow.up")
            }

            // Left / Right
            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    presetButton(preset: .leftTop, icon: "arrow.up.left")
                    presetButton(preset: .leftCenter, icon: "arrow.left")
                    presetButton(preset: .leftBottom, icon: "arrow.down.left")
                }

                VStack(spacing: 6) {
                    presetButton(preset: .rightTop, icon: "arrow.up.right")
                    presetButton(preset: .rightCenter, icon: "arrow.right")
                    presetButton(preset: .rightBottom, icon: "arrow.down.right")
                }
            }

            // Bottom
            HStack {
                presetButton(preset: .bottomCenter, icon: "arrow.down")
            }
        }
    }

    @ViewBuilder
    private func presetButton(preset: DisplayArrangementPreset, icon: String) -> some View {
        let isSelected = (selectedPreset == preset)

        Button(action: {
            onSelect(preset)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(languageManager.currentLanguage.strings.presetLabels(preset))
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }
}
