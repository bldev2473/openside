import AppKit
import SwiftUI
import Combine

/// 메뉴바 아이콘의 좌클릭(팝오버) 및 우클릭(컨텍스트 메뉴) 상호작용을 총괄하는 매니저
@MainActor
public final class StatusItemManager: NSObject, NSPopoverDelegate, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: DisplayManagerViewModel
    private weak var menuHandler: (any MenuBarMenuHandling)?
    private let menuBuilder: StatusItemMenuBuilder
    private let languageManager: any LanguageManaging
    private var cancellables = Set<AnyCancellable>()
    private var lastCloseTime: TimeInterval = 0
    /// 팝오버가 떠 있는 동안만 바깥 클릭을 지켜봅니다.
    private let outsideClick: OutsideClickWatcher
    private var isShowingContextMenu = false

    public init(
        viewModel: DisplayManagerViewModel,
        menuHandler: (any MenuBarMenuHandling)?,
        menuBuilder: StatusItemMenuBuilder = StatusItemMenuBuilder(),
        languageManager: any LanguageManaging = UserDefaultsLanguageManager.shared
    ) {
        self.viewModel = viewModel
        self.menuHandler = menuHandler
        self.menuBuilder = menuBuilder
        self.languageManager = languageManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.outsideClick = OutsideClickWatcher()
        super.init()

        setupPopover()
        setupStatusItem()
        bindViewModel()
    }

    /// 팝오버 속성 및 호스팅 뷰 컨트롤러 초기화
    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let hostingController = NSHostingController(
            rootView: MenuBarPopupView(viewModel: viewModel)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    /// 메뉴바 버튼 액션 및 마우스 이벤트 감지 설정
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        updateIcon(isConnected: viewModel.isSidecarConnected)
        button.target = self
        button.action = #selector(handleButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// 뷰모델 상태 변화 감지하여 메뉴바 아이콘 동적 갱신 및 팝오버 상단 잘림 방지 재배치
    private func bindViewModel() {
        viewModel.$isSidecarConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.updateIcon(isConnected: isConnected)
                self?.repositionPopoverIfNeeded()
            }
            .store(in: &cancellables)

        viewModel.$currentResolution
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPopoverIfNeeded()
            }
            .store(in: &cancellables)

        viewModel.$availableResolutions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPopoverIfNeeded()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPopoverIfNeeded()
            }
            .store(in: &cancellables)
    }

    /// 메뉴바 아이콘 이미지 설정
    private func updateIcon(isConnected: Bool) {
        statusItem.button?.image = MenuBarIcon.image(showsSidecar: isConnected)
    }

    /// 마우스 클릭 이벤트 처리 (좌클릭: 팝오버 토글, 우클릭/Ctrl+좌클릭: 메뉴 노출)
    @objc private func handleButtonClick() {
        if isShowingContextMenu { return }
        guard let event = NSApp.currentEvent else { return }

        let isRightClick = (event.type == .rightMouseUp) ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        if isRightClick {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    /// 팝오버 닫힘 이벤트 수신 (버튼 재클릭 시 순간 재오픈 방지)
    public func popoverDidClose(_ notification: Notification) {
        outsideClick.end()
        lastCloseTime = Date.timeIntervalSinceReferenceDate
    }

    /// 좌클릭 시 팝오버 토글 (상단 잘림 방지를 위해 크기 사전 측정 후 표시)
    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        if now - lastCloseTime < 0.2 {
            return
        }

        // 팝오버가 닫혀 있는 동안 디스플레이 구성이나 시스템 설정이 바뀌었을 수 있으므로
        // 열기 직전에 상태를 다시 읽는다. 사용자가 새로고침을 누를 필요가 없도록.
        viewModel.refreshDisplays()

        // 팝오버 표시 전 최신 뷰 크기 사전 계산 및 적용 (프레임 위쪽 침범 방지)
        if let hostingController = popover.contentViewController as? NSHostingController<MenuBarPopupView> {
            let fittingSize = hostingController.sizeThatFits(in: NSSize(width: 330, height: CGFloat.greatestFiniteMagnitude))
            popover.contentSize = fittingSize
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 메뉴바 앱은 아이콘을 눌러도 활성 앱이 되지 않을 때가 있어, transient 팝오버가
        // 바깥 클릭을 못 받고 열린 채로 남습니다. 전역으로 한 번 더 지켜봅니다.
        outsideClick.begin { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.popover.isShown else { return }
                self.popover.performClose(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.clampPopoverWindowWithinScreen()
        }
    }

    /// 화면 파라미터 변경, 사이드카 연결 상태 또는 해상도 변경 시 팝오버 크기와 위치를 정밀 재계산하여 상단 잘림 방지
    private func repositionPopoverIfNeeded() {
        guard popover.isShown, statusItem.button != nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.popover.isShown, let button = self.statusItem.button else { return }

            if let hostingController = self.popover.contentViewController as? NSHostingController<MenuBarPopupView> {
                let fittingSize = hostingController.sizeThatFits(in: NSSize(width: 330, height: CGFloat.greatestFiniteMagnitude))
                self.popover.contentSize = fittingSize
            }

            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.clampPopoverWindowWithinScreen()
        }
    }

    /// 팝오버 윈도우가 상단 메뉴바 위로 튀어나가 잘리는 현상을 물리적으로 방지
    private func clampPopoverWindowWithinScreen() {
        guard let window = popover.contentViewController?.view.window,
              let screen = window.screen ?? NSScreen.main else { return }

        let maxVisibleY = screen.visibleFrame.maxY
        if window.frame.maxY > maxVisibleY {
            let offset = window.frame.maxY - maxVisibleY
            var newOrigin = window.frame.origin
            newOrigin.y -= offset
            window.setFrameOrigin(newOrigin)
        }
    }

    /// 우클릭 시 4개 항목(정보, 설정, 언어 설정, OpenSide 종료) 컨텍스트 메뉴 노출
    private func showContextMenu() {
        if popover.isShown {
            popover.performClose(nil)
        }

        let menu = menuBuilder.buildMenu(
            target: self,
            currentLanguage: languageManager.currentLanguage,
            aboutAction: #selector(onAboutClicked),
            settingsAction: #selector(onSettingsClicked),
            languageAction: #selector(onLanguageClicked(_:)),
            quitAction: #selector(onQuitClicked)
        )
        menu.delegate = self

        guard let button = statusItem.button else { return }

        // statusItem.menu 에 붙였다 떼는 예전 수법을 쓰지 않습니다. 그렇게 하면 메뉴가 열려
        // 있는 동안 메뉴바에 빈 항목이 하나 더 생기고, 붙어 있는 동안에는 좌클릭까지 이 메뉴를
        // 엽니다. 버튼을 기준으로 직접 띄우면 상태 항목을 건드리지 않습니다.
        //
        // 기준점은 버튼의 좌측 하단입니다. 메뉴의 좌측 상단이 그 자리에 놓여 아래로 펼쳐집니다.
        isShowingContextMenu = true
        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    /// 우클릭 메뉴가 닫히면 좌클릭 팝오버가 다시 동작하도록 표시를 내립니다.
    public func menuDidClose(_ menu: NSMenu) {
        isShowingContextMenu = false
    }

    @objc private func onAboutClicked() {
        menuHandler?.didSelectAbout()
    }

    @objc private func onSettingsClicked() {
        menuHandler?.didSelectSettings()
    }

    @objc private func onLanguageClicked(_ sender: NSMenuItem) {
        if let language = sender.representedObject as? AppLanguage {
            languageManager.setLanguage(language)
            menuHandler?.didSelectLanguage(language)
        }
    }

    @objc private func onQuitClicked() {
        menuHandler?.didSelectTerminate()
    }
}
