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
        super.init()

        setupPopover()
        setupStatusItem()
        bindViewModel()
    }

    /// 팝오버 속성 및 호스팅 뷰 컨트롤러 초기화
    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopupView(viewModel: viewModel)
        )
    }

    /// 메뉴바 버튼 액션 및 마우스 이벤트 감지 설정
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        updateIcon(isConnected: viewModel.isSidecarConnected)
        button.target = self
        button.action = #selector(handleButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// 뷰모델 상태 변화 감지하여 메뉴바 아이콘 동적 갱신
    private func bindViewModel() {
        viewModel.$isSidecarConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.updateIcon(isConnected: isConnected)
            }
            .store(in: &cancellables)
    }

    /// 메뉴바 아이콘 이미지 설정
    private func updateIcon(isConnected: Bool) {
        statusItem.button?.image = NSImage(
            systemSymbolName: isConnected ? "display.2" : "display",
            accessibilityDescription: "OpenSide"
        )
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
        lastCloseTime = Date.timeIntervalSinceReferenceDate
    }

    /// 좌클릭 시 팝오버 토글
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

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
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

        isShowingContextMenu = true
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    /// 우클릭 메뉴가 닫힐 때 statusItem.menu를 즉시 초기화하여 좌클릭 팝오버가 정상 작동하도록 복원
    public func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
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
