import SwiftUI

/// 메뉴바 팝오버 메인 뷰
public struct MenuBarPopupView: View {
    @ObservedObject public var viewModel: DisplayManagerViewModel
    @ObservedObject public var languageManager: UserDefaultsLanguageManager

    public init(
        viewModel: DisplayManagerViewModel,
        languageManager: UserDefaultsLanguageManager = .shared
    ) {
        self.viewModel = viewModel
        self.languageManager = languageManager
    }

    public var body: some View {
        let strings = languageManager.currentLanguage.strings

        VStack(spacing: 12) {
            // 상단 헤더: 타이틀, 연결/해제 버튼, 상태 배지, 새로고침 버튼
            HStack(spacing: 6) {
                Text("OpenSide")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                if viewModel.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else if viewModel.isSidecarConnected {
                    Button(action: {
                        viewModel.disconnectSidecar()
                    }) {
                        Text(strings.disconnect)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if let firstDevice = viewModel.availableSidecarDevices.first {
                    Button(action: {
                        viewModel.connectSidecar(to: firstDevice)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                            Text(strings.connectDevice(firstDevice.name))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // 사이드카 연결 상태 배지
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isSidecarConnected ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)

                    Text(viewModel.isSidecarConnected ? strings.connected : strings.disconnected)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(viewModel.isSidecarConnected ? Color.green : Color.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())

                // 새로고침 버튼
                Button(action: {
                    viewModel.refreshDisplays()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            // 디스플레이 상대 배치 시각화 뷰 (드래그 미세 정렬 연동)
            DisplayVisualizerView(
                mainDisplay: viewModel.mainDisplay,
                sidecarDisplay: viewModel.sidecarDisplay,
                onDragEnded: { targetOrigin in
                    viewModel.applyCustomOrigin(targetOrigin)
                }
            )

            // 사이드카 해상도 선택 및 HiDPI 제어
            if let sidecar = viewModel.sidecarDisplay {
                HStack(spacing: 8) {
                    Text("Sidecar")
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    if !viewModel.availableResolutions.isEmpty {
                        Menu {
                            ForEach(viewModel.availableResolutions) { mode in
                                Button(action: {
                                    viewModel.changeSidecarResolution(mode)
                                }) {
                                    HStack {
                                        Text("\(mode.width) × \(mode.height)")
                                        if mode.width == Int(sidecar.bounds.width) && mode.height == Int(sidecar.bounds.height) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("\(Int(sidecar.bounds.width))×\(Int(sidecar.bounds.height))")
                                    .font(.system(size: 11, design: .monospaced))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    // HiDPI 토글 스위치 (지원 해상도에서만 활성화, 텍스트 잘림 방지)
                    HStack(spacing: 4) {
                        Text("HiDPI")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(viewModel.canToggleHiDPI ? Color.primary : Color.secondary.opacity(0.5))

                        Toggle("", isOn: Binding(
                            get: { viewModel.isCurrentResolutionHiDPI },
                            set: { enable in viewModel.toggleHiDPI(enable) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .disabled(!viewModel.canToggleHiDPI)
                    }
                    .fixedSize()
                }
                .padding(.horizontal, 4)
            }

            Divider()

            // 정렬 프리셋 그리드
            PresetButtonGrid(
                isEnabled: viewModel.isSidecarConnected,
                selectedPreset: viewModel.lastAppliedPreset,
                languageManager: languageManager,
                onSelect: { preset in
                    viewModel.applyPreset(preset)
                }
            )

            // 오류 메시지 표시
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // 하단 조작 바: 마지막 정렬 적용, 앱 종료
            HStack {
                Button(action: {
                    viewModel.applyLastPreset()
                }) {
                    Text(strings.rearrange)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isSidecarConnected)

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text(strings.quit)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
