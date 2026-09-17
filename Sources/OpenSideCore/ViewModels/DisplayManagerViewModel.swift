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
    /// iPad 가 메인 화면을 복제하고 있는지. 복제 중에는 배치가 의미를 잃습니다.
    @Published public private(set) var isSidecarMirrored: Bool = false
    /// 지금 돌고 있는 세션의 지표. 붙어 있지 않으면 nil.
    @Published public private(set) var sessionInfo: SidecarSessionInfo?
    /// 메인 화면이 고를 수 있는 해상도. 복제 중에만 채웁니다.
    ///
    /// 복제 중에는 두 화면의 해상도가 하나이고 그것을 메인 화면이 정합니다. iPad 쪽 모드를
    /// 바꾸면 두 화면이 보고하는 값만 갈라지고 iPad 에 보이는 그림은 그대로입니다.
    /// 바꾸려면 메인을 바꿔야 합니다.
    @Published public private(set) var availableMainResolutions: [DisplayResolutionMode] = []
    @Published public private(set) var availableSidecarDevices: [SidecarDeviceInfo] = []
    /// 기기를 찾지 못했을 때 Mac 쪽에서 확인된 원인. 기기가 있으면 비어 있습니다.
    @Published public private(set) var readinessIssues: [SidecarReadinessIssue] = []
    @Published public private(set) var sidecarBattery: SidecarBatteryInfo?
    /// 현재 잔량으로 더 쓸 수 있는 시간(초). 추정 구현체가 없거나 표본이 모자라면 nil.
    @Published public private(set) var remainingEstimate: TimeInterval?
    @Published public private(set) var isConnecting: Bool = false
    /// 마지막으로 연결에 실패한 기기. 화면에는 쓰지 않습니다.
    /// 자동 연결이 같은 기기에 같은 실패를 되풀이하지 않도록 두는 표시입니다.
    @Published public private(set) var lastConnectFailure: SidecarDeviceInfo?
    /// 마지막으로 연결에 성공한 기기. 화면에는 쓰지 않습니다.
    /// 자동 연결이 어느 기기를 골라야 하는지 여기서 배웁니다.
    @Published public private(set) var lastConnectedDevice: SidecarDeviceInfo?
    @Published public var errorMessage: String?

    private let detector: DisplayDetecting
    private let calculator: ArrangementCalculating
    private let configurator: DisplayConfiguring
    private let presetManager: PresetManaging
    private let modeManager: DisplayModeManaging
    private let sidecarConnector: SidecarConnecting
    private let readinessChecker: SidecarReadinessChecking
    private let batteryReceiver: BatteryReceiving?
    private let remainingTimeEstimator: RemainingTimeEstimating?

    private var screenNotificationObserver: NSObjectProtocol?

    public init(
        detector: DisplayDetecting = CoreGraphicsDisplayDetector(),
        calculator: ArrangementCalculating = StandardArrangementCalculator(),
        configurator: DisplayConfiguring = CoreGraphicsDisplayConfigurator(),
        presetManager: PresetManaging = UserDefaultsPresetManager(),
        modeManager: DisplayModeManaging = CoreGraphicsDisplayModeManager(),
        sidecarConnector: SidecarConnecting = SidecarDeviceManager(),
        readinessChecker: SidecarReadinessChecking = SystemSidecarReadinessChecker(),
        // 배터리 조회 구현체는 쓰는 앱이 넣습니다. 안 넣으면 배지가 표시되지 않습니다.
        batteryReceiver: BatteryReceiving? = nil,
        // 남은 시간 추정도 쓰는 앱이 넣습니다.
        remainingTimeEstimator: RemainingTimeEstimating? = nil
    ) {
        self.detector = detector
        self.calculator = calculator
        self.configurator = configurator
        self.presetManager = presetManager
        self.modeManager = modeManager
        self.sidecarConnector = sidecarConnector
        self.readinessChecker = readinessChecker
        self.batteryReceiver = batteryReceiver
        self.remainingTimeEstimator = remainingTimeEstimator
        self.lastAppliedPreset = presetManager.loadLastPreset()

        setupBatteryReceiver()
        refreshDisplays()
        setupScreenChangeObserver()
    }

    deinit {
        batteryReceiver?.stopListening()
        if let observer = screenNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// 배터리 수신 서비스 리스너 등록 및 데이터 바인딩
    private func setupBatteryReceiver() {
        batteryReceiver?.onBatteryUpdate = { [weak self] battery in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.sidecarBattery = battery

                // iPad 를 못 읽으면 추정도 의미가 없다.
                guard let battery else {
                    self.remainingEstimate = nil
                    return
                }
                // 기록이 쌓이면서 추정이 달라지므로 값을 받을 때마다 다시 계산합니다.
                self.remainingEstimate = self.remainingTimeEstimator?
                    .estimatedRemaining(currentBattery: battery.percentage)
            }
        }
        batteryReceiver?.startListening()
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

    /// 모드 변경이 시스템에 반영된 뒤에 상태를 다시 읽습니다.
    ///
    /// 해상도 변경은 즉시 끝나지 않습니다. 복제 중에 재 보니 반영까지 0.48초가 걸렸습니다.
    /// 예전에는 0.2초 뒤 한 번만 읽어 옛 값을 그대로 화면에 남겼습니다.
    /// 두 번 읽는 것은 느린 기기에서 첫 번째가 일러도 두 번째가 받도록 하기 위함입니다.
    private func refreshAfterModeChange() {
        for delay in [0.6, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
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

        self.isSidecarMirrored = self.sidecarDisplay?.isMirrored ?? false

        if self.isSidecarMirrored, let main = self.mainDisplay {
            self.availableMainResolutions = modeManager.getAvailableModes(displayID: main.id)
        } else {
            self.availableMainResolutions = []
        }

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
        self.sessionInfo = self.isSidecarConnected ? sidecarConnector.currentSessionInfo() : nil
        // 목록에 기기가 남아 있어도 전제 조건이 깨졌으면 연결은 실패하므로 항상 점검합니다.
        self.readinessIssues = self.isSidecarConnected ? [] : readinessChecker.currentIssues()
        self.errorMessage = nil
    }

    /// 연결 가능한 기기 목록만 다시 읽습니다. 디스플레이 구성은 건드리지 않습니다.
    ///
    /// `refreshDisplays()` 는 화면 열거와 해상도 목록까지 다시 만듭니다. 배경에서 자주
    /// 부르려면 그만큼이 필요 없습니다. 이쪽은 SidecarCore 가 이미 들고 있는 배열을
    /// 읽는 것이 전부입니다(측정: 호출당 0.0011 ms).
    public func refreshSidecarDevices() {
        self.availableSidecarDevices = sidecarConnector.getAvailableDevices()
    }

    /// 현재 해상도에서 HiDPI 모드 활성화 여부를 토글합니다.
    public func toggleHiDPI(_ enabled: Bool) {
        guard let sidecar = sidecarDisplay else { return }
        let result = modeManager.toggleHiDPI(displayID: sidecar.id, enable: enabled)
        switch result {
        case .success:
            self.isCurrentResolutionHiDPI = enabled
            self.errorMessage = nil
            refreshAfterModeChange()
        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    /// iPad 가 메인 화면을 복제하도록 하거나 복제를 풀어 확장으로 되돌립니다.
    ///
    /// 자동으로 부르지 않습니다. 복제는 메인 화면 전부를 iPad 로 내보내므로, 무엇을 보낼지
    /// 사용자가 매번 고르게 둡니다.
    public func toggleMirroring(_ enable: Bool) {
        guard let sidecar = sidecarDisplay else {
            errorMessage = "연결된 사이드카 디스플레이가 없습니다."
            return
        }
        guard let main = mainDisplay else {
            errorMessage = "메인 디스플레이를 찾을 수 없습니다."
            return
        }

        // 로그아웃하면 확장으로 돌아갑니다. 영구로 쓰면 macOS 가 이 디스플레이의 복제
        // 설정을 기억해 iPad 를 새로 연결해도 복제 상태로 붙습니다. 복제는 그 세션 동안의
        // 선택이지 기기에 남길 설정이 아닙니다.
        let result = configurator.configureMirroring(
            displayID: sidecar.id,
            mirrorOf: enable ? main.id : nil,
            persistence: .session
        )

        switch result {
        case .success:
            self.isSidecarMirrored = enable
            self.errorMessage = nil
            // 복제를 켜고 끄면 디스플레이 구성이 통째로 다시 섭니다.
            refreshAfterModeChange()

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
                // 실패는 표시하지 않습니다. SidecarCore 가 자체 알림창을 띄우고, 그쪽 설명이
                // 더 구체적입니다. 여기서 또 보여주면 같은 말이 두 번 나옵니다.
                self?.errorMessage = nil
                switch result {
                case .success:
                    self?.lastConnectFailure = nil
                    self?.lastConnectedDevice = device
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.refreshDisplays()
                    }
                case .failure:
                    self?.lastConnectFailure = device
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
                // 연결과 같은 이유로 실패를 표시하지 않습니다.
                self?.errorMessage = nil
                if case .success = result {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.refreshDisplays()
                    }
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

        let result = modeManager.setDisplayResolution(displayID: sidecar.id, mode: mode, persistence: .permanent)

        switch result {
        case .success:
            self.currentResolution = mode
            self.errorMessage = nil
            refreshAfterModeChange()

        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    /// 메인 화면의 해상도를 변경합니다. 복제 중에는 iPad 도 같이 따라갑니다.
    ///
    /// Mac 본체 화면이 바뀌는 조작이므로 화면에서도 대상이 메인임을 밝혀야 합니다.
    public func changeMainResolution(_ mode: DisplayResolutionMode) {
        guard let main = mainDisplay else {
            errorMessage = "메인 디스플레이를 찾을 수 없습니다."
            return
        }

        // 로그아웃하면 원래대로 돌아갑니다. 복제 중 해상도는 Sidecar 세션에 딸린 임시
        // 조정인데, 바뀌는 대상은 Mac 본체 화면입니다. 이 도구가 남길 자국이 아닙니다.
        switch modeManager.setDisplayResolution(displayID: main.id, mode: mode, persistence: .session) {
        case .success:
            self.errorMessage = nil
            refreshAfterModeChange()
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
            // 저장소도 같이 비운다. 메모리만 지우면 다음 실행에서 옛 프리셋이 되살아난다.
            self.lastAppliedPreset = nil
            self.presetManager.clearLastPreset()
            self.errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshDisplays()
            }

        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }
}
