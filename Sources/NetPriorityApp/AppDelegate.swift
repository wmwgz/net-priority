import AppKit
import Combine
import SwiftUI
import NetPriorityCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var viewModel: AppViewModel!
    private var mainWindow: NSWindow!
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private var showWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.gao.netpriority"
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existingInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID }
        let launchedInBackground = CommandLine.arguments.contains("--background")

        if !existingInstances.isEmpty {
            if !launchedInBackground {
                DistributedNotificationCenter.default().postNotificationName(
                    Notification.Name("com.gao.netpriority.showMainWindow"),
                    object: nil,
                    userInfo: nil,
                    deliverImmediately: true
                )
            }
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.regular)

        showWindowObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.gao.netpriority.showMainWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showMainWindow()
            }
        }

        viewModel = AppViewModel()

        let hosting = NSHostingView(rootView: MainView(viewModel: viewModel))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.windowTitle(viewModel.lang)
        window.contentView = hosting
        window.setContentSize(NSSize(width: 780, height: 600))
        window.minSize = NSSize(width: 720, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        mainWindow = window

        setupMainMenu()
        setupStatusBar()
        bindStatusUpdates()

        if !launchedInBackground {
            showMainWindow()
        }
    }

    private func setupMainMenu() {
        let l = viewModel.lang
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.mainMenuHide(l), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.menuBarQuit(l), action: #selector(handleQuit), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.mainMenuEdit(l))
        editMenu.addItem(withTitle: L10n.mainMenuUndo(l), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.mainMenuRedo(l), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.mainMenuCut(l), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.mainMenuCopy(l), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.mainMenuPaste(l), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.mainMenuSelectAll(l), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: L10n.mainMenuWindow(l))
        windowMenu.addItem(withTitle: L10n.menuBarOpenWindow(l), action: #selector(handleOpenWindow), keyEquivalent: "o")
        windowMenu.addItem(withTitle: L10n.menuBarRefresh(l), action: #selector(handleRefresh), keyEquivalent: "r")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: L10n.mainMenuCloseWindow(l), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L10n.mainMenuMinimize(l), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBar()
    }

    private func bindStatusUpdates() {
        Publishers.CombineLatest4(viewModel.$services, viewModel.$routeInfo, viewModel.$launchAtLogin, viewModel.$appLanguage)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self else { return }
                self.mainWindow.title = L10n.windowTitle(self.viewModel.lang)
                self.setupMainMenu()
                self.updateStatusBar()
            }
            .store(in: &cancellables)
    }

    private func updateStatusBar() {
        guard let button = statusItem.button else { return }
        let l = viewModel.lang

        let exit = viewModel.defaultExitService
        let symbolName = exit?.kind.systemImage ?? "wifi.slash"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: L10n.currentDefaultExit(l)) {
            img.isTemplate = true
            button.image = img
        }
        button.imagePosition = .imageLeading

        if let exit {
            let shortName = exit.kind == .wifi ? "Wi-Fi" : exit.displayName
            button.title = " \(shortName)"
        } else {
            button.title = " \(L10n.menuBarNoExitShort(l))"
        }

        let menu = NSMenu()

        if let exit {
            let ipText = exit.effectiveIPv4.isEmpty ? L10n.menuBarNoIP(l) : exit.effectiveIPv4
            let header = NSMenuItem(title: L10n.menuBarCurrentExit(exit.displayName, ip: ipText, l), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        } else {
            let header = NSMenuItem(title: L10n.menuBarNoDefaultExit(l), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }

        if !viewModel.routeInfo.ipv4Gateway.isEmpty {
            let gw = NSMenuItem(title: L10n.menuBarGateway(viewModel.routeInfo.ipv4Gateway, iface: viewModel.routeInfo.ipv4Interface, l), action: nil, keyEquivalent: "")
            gw.isEnabled = false
            menu.addItem(gw)
        }

        menu.addItem(.separator())

        let wifiItem = NSMenuItem(title: L10n.menuBarPreferWiFi(l), action: #selector(handlePrioritizeWiFi), keyEquivalent: "1")
        wifiItem.target = self
        if let wifi = viewModel.wifiService {
            wifiItem.state = (viewModel.visibleServices.first?.id == wifi.id) ? .on : .off
        } else {
            wifiItem.isEnabled = false
        }
        menu.addItem(wifiItem)

        let wiredList = viewModel.wiredCandidates
        if !wiredList.isEmpty {
            let sectionTitle = NSMenuItem(title: L10n.menuBarSwitchWiredHeader(l), action: nil, keyEquivalent: "")
            sectionTitle.isEnabled = false
            menu.addItem(sectionTitle)

            for dev in wiredList {
                let tag = dev.config.isManagementOnly ? L10n.modeManagementOnly(l) : dev.linkStatus.localizedLabel(in: l)
                let title = "  \(dev.displayName) [\(dev.device.isEmpty ? "-" : dev.device) · \(tag)]"
                let item = NSMenuItem(title: title, action: #selector(handlePrioritizeNamed(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = dev.serviceName
                item.state = (viewModel.visibleServices.first?.id == dev.id) ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: L10n.menuBarOpenWindow(l), action: #selector(handleOpenWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: L10n.menuBarRefresh(l), action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let langRootItem = NSMenuItem(title: "\(L10n.languageLabel(l)) / Language", action: nil, keyEquivalent: "")
        let langSubmenu = NSMenu()
        for option in AppLanguage.allCases {
            let mi = NSMenuItem(title: option.menuTitle(in: l), action: #selector(handleSelectLanguage(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = option.rawValue
            mi.state = (viewModel.appLanguage == option) ? .on : .off
            langSubmenu.addItem(mi)
        }
        langRootItem.submenu = langSubmenu
        menu.addItem(langRootItem)

        let loginItem = NSMenuItem(title: L10n.launchAtLogin(l), action: #selector(handleToggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = viewModel.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.menuBarQuit(l), action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func handlePrioritizeWiFi() {
        viewModel.prioritizeWiFi()
    }

    @objc private func handlePrioritizeNamed(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        viewModel.prioritizeWired(serviceName: name)
    }

    @objc private func handleOpenWindow() {
        showMainWindow()
    }

    @objc private func handleRefresh() {
        Task { await viewModel.refresh() }
    }

    @objc private func handleSelectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let chosen = AppLanguage(rawValue: raw) else { return }
        viewModel.appLanguage = chosen
    }

    @objc private func handleToggleLaunchAtLogin() {
        viewModel.setLaunchAtLogin(!viewModel.launchAtLogin)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.makeKeyAndOrderFront(nil)
    }
}
