import SwiftUI

/// Main view for menu bar popover.
public struct MenuBarPopupView: View {
    /// Converts seconds to human-readable duration using localized formatting.
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
            // Top header: title, connect/disconnect button, status badge, refresh button
            HStack(spacing: 5) {
                Text("OpenSide")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 4)

                // iPad battery and remaining time estimate (visible only during Sidecar connection)
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

                // Session framerate. Bottlenecks on wireless connections become apparent here first.
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

                // Sidecar connection status badge
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

                // Refresh button
                Button(action: {
                    viewModel.refreshDisplays()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            // Whether extending or mirroring determines the meaning of the diagram and everything below it,
            // so this control is placed at the very top, directly preceding the diagram.
            //
            // Mirroring is not turned on automatically. The entire main display is output to iPad,
            // so the user explicitly chooses what to display each time.
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

            // Display relative arrangement visualizer view (supports drag fine adjustment)
            DisplayVisualizerView(
                mainDisplay: viewModel.mainDisplay,
                sidecarDisplay: viewModel.sidecarDisplay,
                isMirrored: viewModel.isSidecarMirrored,
                onDragEnded: { targetOrigin in
                    viewModel.applyCustomOrigin(targetOrigin)
                }
            )

            // During mirroring, select the main display resolution. The mirrored set shares a single resolution
            // determined by the main display; changing iPad mode only diverges reported values without altering output.
            // Since the Mac primary display changes, label explicitly identifies the target as main display.
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

            // Resolution selection: active only in extended desktop mode.
            //
            // While mirroring a canvas, select the canvas size. The canvas determines the actual rendered size,
            // and changing iPad mode only causes values to diverge. HiDPI toggle is omitted;
            // canvas is always rendered at double logical size.
            if viewModel.sidecarDisplay != nil, !viewModel.isSidecarMirrored, viewModel.isShowingCanvas {
                HStack(spacing: 6) {
                    Text(strings.resolution)
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    Picker("", selection: Binding<DisplayResolutionMode?>(
                        get: { viewModel.currentCanvasSize },
                        set: { mode in
                            if let mode { viewModel.changeCanvasSize(mode) }
                        }
                    )) {
                        ForEach(viewModel.availableCanvasSizes) { mode in
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

            // Sidecar native resolution selection and HiDPI control (when not using canvas).
            if viewModel.sidecarDisplay != nil, !viewModel.isSidecarMirrored, !viewModel.isShowingCanvas {
                HStack(spacing: 6) {
                    Text(strings.resolution)
                        .font(.system(size: 11, weight: .medium))

                    Spacer()

                    if !viewModel.availableResolutions.isEmpty {
                        // Use Picker. In Menu, Button labels are flattened into menu items and HStack checkmark Images
                        // are stripped, failing to show the current selection. Picker renders selection indicators natively via macOS.
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

                    // HiDPI toggle switch (enabled only for supported resolutions, avoids text truncation)
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

            // Displays arrangement presets or connect button depending on connection state
            if viewModel.isSidecarConnected {
                // Arrangement cannot be changed during mirroring. Both displays share a single logical surface with one coordinate origin.
                // Since it is connected, do not fall through to the connection button branch below.
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
                        // Place progress indicator inside the button. Keeps status visible right where clicked,
                        // and prevents button disappearance and list jitter.
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
                    // Displays battery level before connecting, allowing users to assess whether to connect or charge first.
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

            // Notify when prerequisites are broken regardless of device list. Connection will fail even if listed.
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
                        // Center text and pin shortcut icon to trailing edge.
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

            // Error message display
            if let failure = viewModel.failure {
                Text(failure.message(strings))
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Bottom action bar: apply last preset, disconnect, quit app
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
