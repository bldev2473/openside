import AppKit
import SwiftUI
import Combine

/// Manager overseeing left-click (popover) and right-click (context menu) interactions on the menu bar item
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
    /// Watches for outside clicks only while the popover is presented.
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

    /// Initializes popover properties and hosting view controller
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

    /// Configures status item button actions and mouse click event tracking
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        updateIcon(isConnected: viewModel.isSidecarConnected)
        button.target = self
        button.action = #selector(handleButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Observes view model changes to update menu bar icon and reposition popover to prevent clipping
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

    /// Configures menu bar icon image
    private func updateIcon(isConnected: Bool) {
        statusItem.button?.image = MenuBarIcon.image(showsSidecar: isConnected)
    }

    /// Handles mouse click events (Left: toggle popover, Right/Ctrl+Left: show context menu)
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

    /// Receives popover close event (debounces rapid re-opening on button clicks)
    public func popoverDidClose(_ notification: Notification) {
        outsideClick.end()
        lastCloseTime = Date.timeIntervalSinceReferenceDate
    }

    /// Toggles popover on left click (pre-calculates size to prevent clipping against menu bar)
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

        // Re-read display configuration and system settings immediately before opening
        // in case anything changed while the popover was closed.
        viewModel.refreshDisplays()

        // Measure and apply fitting size before presentation
        if let hostingController = popover.contentViewController as? NSHostingController<MenuBarPopupView> {
            let fittingSize = hostingController.sizeThatFits(in: NSSize(width: 330, height: CGFloat.greatestFiniteMagnitude))
            popover.contentSize = fittingSize
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Menu bar apps do not always become the active application upon clicking the icon,
        // which can prevent transient popovers from receiving outside clicks. Watch globally.
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

    /// Recalculates size and repositions popover on parameter/connection/resolution changes to avoid clipping
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

    /// Clamps popover window frame to remain within the visible screen area below the menu bar
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

    /// Presents context menu with 4 items (About, Settings, Language, Quit OpenSide) on right click
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

        // Do not attach/detach from statusItem.menu. Doing so creates a blank extra item
        // in the menu bar while open and causes subsequent left-clicks to open the menu.
        // Presenting directly relative to button leaves status item state intact.
        //
        // Positioned at the bottom-left of the button so the menu opens downward.
        isShowingContextMenu = true
        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    /// Resets flag when context menu closes so left-click popover works again
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
