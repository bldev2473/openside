import SwiftUI

/// 메뉴바 팝오버 메인 뷰
public struct MenuBarPopupView: View {
    /// 초를 사람이 읽는 길이로. 지역에 맞는 표기를 시스템에 맡긴다.
    static func durationText(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(
            .units(allowed: [.hours, .minutes], width: .narrow)
        )
    }

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
            HStack(spacing: 5) {
                Text("OpenSide")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 4)

                // iPad 배터리와 남은 시간 추정 (Sidecar 연결 중에만 노출)
                if viewModel.isSidecarConnected, let battery = viewModel.sidecarBattery {
                    HStack(spacing: 2) {
                        Image(systemName: battery.iconName)
                            .font(.system(size: 10))
                            .foregroundStyle(battery.iconColor)
                        Text("\(battery.percentage)%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if let remaining = viewModel.remainingEstimate {
                            Text(verbatim: "·")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Text(strings.approximateRemaining(Self.durationText(remaining)))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                    .help(strings.iPadBatteryTooltip(
                        battery.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    ))
                }

                // 사이드카 연결 상태 배지
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isSidecarConnected ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)

                    Text(viewModel.isSidecarConnected ? strings.connected : strings.disconnected)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(viewModel.isSidecarConnected ? Color.green : Color.secondary)
                }
                .opacity(viewModel.isSidecarConnected ? 1 : 0.5)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)

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
                HStack(spacing: 6) {
                    Text(strings.resolution)
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
                                Text("\(Int(sidecar.bounds.width)) × \(Int(sidecar.bounds.height))")
                                    .font(.system(size: 11, design: .monospaced))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                        .menuStyle(.borderlessButton)
                        // SwiftUI 가 표시기를 하나 더 그린다. 위 라벨의 chevron 만 남긴다.
                        .menuIndicator(.hidden)
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

            // 연결 상태에 따라 정렬 프리셋 또는 연결 버튼을 노출
            if viewModel.isSidecarConnected {
                PresetButtonGrid(
                    isEnabled: true,
                    selectedPreset: viewModel.lastAppliedPreset,
                    languageManager: languageManager,
                    onSelect: { preset in
                        viewModel.applyPreset(preset)
                    }
                )
            } else if let firstDevice = viewModel.availableSidecarDevices.first {
                Button(action: {
                    viewModel.connectSidecar(to: firstDevice)
                }) {
                    HStack(spacing: 5) {
                        // 진행 표시를 버튼 안에 둔다. 누른 자리에서 상태가 보이고,
                        // 버튼이 사라졌다 돌아오지 않아 목록이 흔들리지 않는다.
                        if viewModel.isConnecting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                        }
                        Text(strings.connectDevice(firstDevice.name))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    // 연결 전에도 잔량을 보여준다. 지금 붙일지 충전부터 할지 여기서 판단한다.
                    .overlay(alignment: .trailing) {
                        if let battery = viewModel.sidecarBattery {
                            HStack(spacing: 2) {
                                Image(systemName: battery.iconName)
                                    .font(.system(size: 10))
                                Text("\(battery.percentage)%")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))

                                if let remaining = viewModel.remainingEstimate {
                                    Text(verbatim: "·")
                                        .font(.system(size: 10))
                                        .opacity(0.6)
                                    Text(Self.durationText(remaining))
                                        .font(.system(size: 10))
                                }
                            }
                            .padding(.trailing, 10)
                        }
                    }
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isConnecting)
            } else {
                Text(strings.noSidecarDevices)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            // 전제 조건이 깨졌으면 기기 목록과 무관하게 알립니다. 목록에 남아 있어도 연결은 실패합니다.
            ForEach(viewModel.readinessIssues, id: \.self) { issue in
                VStack(spacing: 4) {
                    Button(action: {
                        if let url = issue.settingsURL {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(strings.readinessHint(issue))
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        // 문구는 가운데 두고 바로가기 아이콘만 우측 끝에 고정합니다.
                        .overlay(alignment: .trailing) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .font(.system(size: 11))
                                .padding(.trailing, 10)
                        }
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(issue.settingsURL == nil)

                    Text(strings.readinessCallToAction)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // 오류 메시지 표시
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // 하단 조작 바: 마지막 정렬 적용, 연결 해제, 앱 종료
            HStack(spacing: 8) {
                if viewModel.isSidecarConnected {
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
                }

                Spacer()

                if viewModel.isSidecarConnected {
                    Button(action: {
                        viewModel.disconnectSidecar()
                    }) {
                        HStack(spacing: 4) {
                            if viewModel.isConnecting {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            }
                            Text(strings.disconnect)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.red.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isConnecting)
                }

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text(strings.quit)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 330)
    }
}
