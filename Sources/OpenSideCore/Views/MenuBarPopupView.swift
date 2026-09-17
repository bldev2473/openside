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

                // 세션 프레임레이트. 무선이 느릴 때 여기서 먼저 드러납니다.
                if let session = viewModel.sessionInfo {
                    Text("\(session.framerate) Hz")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
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

            // 확장이냐 복제냐가 도식과 그 아래 모든 것의 뜻을 정합니다. 그래서 맨 위,
            // 도식 바로 앞에 둡니다.
            //
            // 복제는 자동으로 켜지지 않습니다. 메인 화면 전부가 iPad 로 나가므로
            // 무엇을 보낼지 사용자가 매번 고릅니다.
            if viewModel.isSidecarConnected {
                Picker("", selection: Binding(
                    get: { viewModel.isSidecarMirrored },
                    set: { mirror in viewModel.toggleMirroring(mirror) }
                )) {
                    Text(strings.extendDisplay).tag(false)
                    Text(strings.mirrorDisplay).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            // 디스플레이 상대 배치 시각화 뷰 (드래그 미세 정렬 연동)
            DisplayVisualizerView(
                mainDisplay: viewModel.mainDisplay,
                sidecarDisplay: viewModel.sidecarDisplay,
                isMirrored: viewModel.isSidecarMirrored,
                onDragEnded: { targetOrigin in
                    viewModel.applyCustomOrigin(targetOrigin)
                }
            )

            // 복제 중에는 메인 화면 해상도를 고릅니다. 미러 세트는 해상도가 하나이고
            // 메인이 그것을 정합니다. iPad 쪽 모드를 바꾸면 값만 갈라지고 그림은 그대로였습니다.
            // Mac 본체 화면도 함께 바뀌므로 라벨에 대상이 메인임을 밝힙니다.
            if viewModel.isSidecarMirrored, !viewModel.availableMainResolutions.isEmpty {
                HStack(spacing: 6) {
                    Text(strings.mainResolution)
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    Picker("", selection: Binding<DisplayResolutionMode?>(
                        get: { viewModel.availableMainResolutions.first { $0.isCurrent } },
                        set: { mode in
                            if let mode { viewModel.changeMainResolution(mode) }
                        }
                    )) {
                        ForEach(viewModel.availableMainResolutions) { mode in
                            Text("\(mode.width) × \(mode.height)")
                                .tag(DisplayResolutionMode?.some(mode))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                }
                .padding(.horizontal, 4)
            }

            // 사이드카 해상도 선택 및 HiDPI 제어. 확장일 때만입니다.
            if viewModel.sidecarDisplay != nil, !viewModel.isSidecarMirrored {
                HStack(spacing: 6) {
                    Text(strings.resolution)
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    if !viewModel.availableResolutions.isEmpty {
                        // Picker 를 씁니다. Menu 안의 Button 라벨은 메뉴 항목으로 평탄화되면서
                        // HStack 안의 체크마크 Image 가 버려져 현재 항목이 표시되지 않았습니다.
                        // Picker 는 선택 표시를 macOS 가 직접 그립니다.
                        Picker("", selection: Binding<DisplayResolutionMode?>(
                            get: { viewModel.availableResolutions.first { $0.isCurrent } },
                            set: { mode in
                                if let mode { viewModel.changeSidecarResolution(mode) }
                            }
                        )) {
                            ForEach(viewModel.availableResolutions) { mode in
                                Text("\(mode.width) × \(mode.height)")
                                    .tag(DisplayResolutionMode?.some(mode))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .controlSize(.small)
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

            // 연결 상태에 따라 정렬 프리셋 또는 연결 버튼을 노출
            if viewModel.isSidecarConnected {
                // 복제 중에는 배치를 바꿀 수 없습니다. 두 화면이 한 화면이라 좌표가 하나뿐입니다.
                // 연결된 상태이므로 아래 연결 버튼 분기로 떨어지면 안 됩니다.
                if !viewModel.isSidecarMirrored {
                    PresetButtonGrid(
                        isEnabled: true,
                        selectedPreset: viewModel.lastAppliedPreset,
                        languageManager: languageManager,
                        onSelect: { preset in
                            viewModel.applyPreset(preset)
                        }
                    )
                }
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
