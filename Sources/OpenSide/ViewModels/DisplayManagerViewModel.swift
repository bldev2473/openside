import Foundation
import SwiftUI
import Combine
import CoreGraphics

/// 사이드카 상태 및 디스플레이 정렬 제어를 총괄하는 메인 뷰모델
@MainActor
public final class DisplayManagerViewModel: ObservableObject {
    @Published public private(set) var displays: [DisplayInfo] = []
    @Published public private(set) var mainDisplay: DisplayInfo?
    @Published public private(set) var sidecarDisplay: DisplayInfo?
    @Published public private(set) var isSidecarConnected: Bool = false
    @Published public private(set) var lastAppliedPreset: DisplayArrangementPreset?
    @Published public private(set) var availableResolutions: [DisplayResolutionMode] = []
    @Published public private(set) var currentResolution: DisplayResolutionMode?
    @Published public private(set) var isCurrentResolutionHiDPI: Bool = false
    @Published public private(set) var canToggleHiDPI: Bool = false
    @Published public private(set) var availableSidecarDevices: [SidecarDeviceInfo] = []
    @Published public private(set) var isConnecting: Bool = false
    @Published public var errorMessage: String?

    private let detector: DisplayDetecting
    private let calculator: ArrangementCalculating
    private let configurator: DisplayConfiguring
    private let presetManager: PresetManaging
    private let modeManager: DisplayModeManaging
    private let sidecarConnector: SidecarConnecting

    private var screenNotificationObserver: NSObjectProtocol?

    public init(
        detector: DisplayDetecting = CoreGraphicsDisplayDetector(),
        calculator: ArrangementCalculating = StandardArrangementCalculator(),
        configurator: DisplayConfiguring = CoreGraphicsDisplayConfigurator(),
        presetManager: PresetManaging = UserDefaultsPresetManager(),
        modeManager: DisplayModeManaging = CoreGraphicsDisplayModeManager(),
        sidecarConnector: SidecarConnecting = SidecarDeviceManager()
    ) {
        self.detector = detector
        self.calculator = calculator
        self.configurator = configurator
        self.presetManager = presetManager
        self.modeManager = modeManager
        self.sidecarConnector = sidecarConnector
        self.lastAppliedPreset = presetManager.loadLastPreset()

        refreshDisplays()
        setupScreenChangeObserver()
    }

    deinit {
        if let observer = screenNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 화면 변경 이벤트 감지 리스너 등록
    private func setupScreenChangeObserver() {
        screenNotificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplays()
            }
        }
    }

    /// 현재 시스템의 디스플레이 상태를 새로고침합니다.
    public func refreshDisplays() {
        let activeDisplays = detector.getActiveDisplays()
        self.displays = activeDisplays
        self.mainDisplay = detector.getMainDisplay()
        self.sidecarDisplay = detector.getSidecarDisplay()
        self.isSidecarConnected = (self.sidecarDisplay != nil)

        if let sidecar = self.sidecarDisplay {
            self.availableResolutions = modeManager.getAvailableModes(displayID: sidecar.id)
            let curr = modeManager.getCurrentMode(displayID: sidecar.id)
            self.currentResolution = curr
            self.isCurrentResolutionHiDPI = curr?.isHiDPI ?? false
            self.canToggleHiDPI = modeManager.canToggleHiDPI(displayID: sidecar.id)
        } else {
            self.availableResolutions = []
            self.currentResolution = nil
            self.isCurrentResolutionHiDPI = false
            self.canToggleHiDPI = false
        }

        self.availableSidecarDevices = sidecarConnector.getAvailableDevices()
        self.errorMessage = nil
    }

    /// 현재 해상도에서 HiDPI 모드 활성화 여부를 토글합니다.
    public func toggleHiDPI(_ enabled: Bool) {
        guard let sidecar = sidecarDisplay else { return }
        let result = modeManager.toggleHiDPI(displayID: sidecar.id, enable: enabled)
        switch result {
        case .success:
            self.isCurrentResolutionHiDPI = enabled
            self.errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.refreshDisplays()
            }
        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    /// 특정 사이드카 장치로 즉시 연결을 시작합니다.
    public func connectSidecar(to device: SidecarDeviceInfo) {
        self.isConnecting = true
        self.errorMessage = nil

        sidecarConnector.connect(to: device) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isConnecting = false
                switch result {
                case .success:
                    self?.errorMessage = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.refreshDisplays()
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 현재 연결된 사이드카 세션을 종료합니다.
    public func disconnectSidecar() {
        self.isConnecting = true
        self.errorMessage = nil

        sidecarConnector.disconnect { [weak self] result in
            Task { @MainActor [weak self] in
                self?.isConnecting = false
                switch result {
                case .success:
                    self?.errorMessage = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.refreshDisplays()
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 사이드카 디스플레이의 해상도를 변경합니다.
    public func changeSidecarResolution(_ mode: DisplayResolutionMode) {
        guard let sidecar = sidecarDisplay else {
            errorMessage = "연결된 사이드카 디스플레이가 없습니다."
            return
        }

        let result = modeManager.setDisplayResolution(displayID: sidecar.id, mode: mode)

        switch result {
        case .success:
            self.currentResolution = mode
            self.errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.refreshDisplays()
            }

        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    /// 특정 프리셋을 적용하여 사이드카 디스플레이 배치를 즉시 변경합니다.
    public func applyPreset(_ preset: DisplayArrangementPreset) {
        guard let main = mainDisplay else {
            errorMessage = "메인 디스플레이를 찾을 수 없습니다."
            return
        }

        guard let sidecar = sidecarDisplay else {
            errorMessage = "연결된 사이드카 디스플레이가 없습니다."
            return
        }

        let targetOrigin = calculator.calculateOrigin(
            mainBounds: main.bounds,
            targetBounds: sidecar.bounds,
            preset: preset
        )

        let result = configurator.configureDisplayOrigin(
            displayID: sidecar.id,
            origin: targetOrigin
        )

        switch result {
        case .success:
            self.lastAppliedPreset = preset
            self.presetManager.saveLastPreset(preset)
            self.errorMessage = nil
            // 변경 후 상태 갱신
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshDisplays()
            }

        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    /// 마지막으로 저장된 프리셋으로 즉시 복원합니다.
    public func applyLastPreset() {
        if let preset = lastAppliedPreset ?? presetManager.loadLastPreset() {
            applyPreset(preset)
        } else {
            // 기본값: 좌측 중앙
            applyPreset(.leftCenter)
        }
    }

    /// 드래그 앤 드롭 등으로 산출된 임의의 목표 좌표를 즉시 시스템에 적용합니다.
    public func applyCustomOrigin(_ origin: TargetDisplayOrigin) {
        guard let sidecar = sidecarDisplay else {
            errorMessage = "연결된 사이드카 디스플레이가 없습니다."
            return
        }

        let result = configurator.configureDisplayOrigin(
            displayID: sidecar.id,
            origin: origin
        )

        switch result {
        case .success:
            self.lastAppliedPreset = nil
            self.errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshDisplays()
            }

        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }
}
