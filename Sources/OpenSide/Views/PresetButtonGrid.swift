import SwiftUI

/// 디스플레이 원클릭 정렬 프리셋 버튼 그리드 뷰
public struct PresetButtonGrid: View {
    public let isEnabled: Bool
    public let selectedPreset: DisplayArrangementPreset?
    public let onSelect: (DisplayArrangementPreset) -> Void

    public init(
        isEnabled: Bool,
        selectedPreset: DisplayArrangementPreset?,
        onSelect: @escaping (DisplayArrangementPreset) -> Void
    ) {
        self.isEnabled = isEnabled
        self.selectedPreset = selectedPreset
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 상단
            HStack {
                presetButton(preset: .topCenter, icon: "arrow.up")
            }

            // 좌측 / 우측
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

            // 하단
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
                Text(preset.label)
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
