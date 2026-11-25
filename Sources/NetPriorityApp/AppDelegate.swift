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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        viewModel = AppViewModel()

        let hosting = NSHostingView(rootView: MainView(viewModel: viewModel))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "网卡优先级管理 (NetPriority)"
        window.contentView = hosting
        window.setContentSize(NSSize(width: 780, height: 600))
        window.minSize = NSSize(width: 700, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        mainWindow = window

        setupStatusBar()
        bindStatusUpdates()

        let launchedInBackground = CommandLine.arguments.contains("--background")
        if !launchedInBackground {
            showMainWindow()
        }
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
        Publishers.CombineLatest3(viewModel.$services, viewModel.$routeInfo, viewModel.$launchAtLogin)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateStatusBar()
            }
            .store(in: &cancellables)
    }

    private func updateStatusBar() {
        guard let button = statusItem.button else { return }

        let exit = viewModel.defaultExitService
        let symbolName = exit?.kind.systemImage ?? "wifi.slash"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "网络出口") {
            img.isTemplate = true
            button.image = img
        }
        button.imagePosition = .imageLeading

        if let exit {
            let shortName = exit.kind == .wifi ? "Wi-Fi" : exit.displayName
            button.title = " \(shortName)"
        } else {
            button.title = " 无出口"
        }

        let menu = NSMenu()

        if let exit {
            let ipText = exit.effectiveIPv4.isEmpty ? "无 IP" : exit.effectiveIPv4
            let header = NSMenuItem(title: "当前出口：\(exit.displayName)（\(ipText)）", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        } else {
            let header = NSMenuItem(title: "当前无默认上网出口", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }

        if !viewModel.routeInfo.ipv4Gateway.isEmpty {
            let gw = NSMenuItem(title: "默认网关：\(viewModel.routeInfo.ipv4Gateway) (\(viewModel.routeInfo.ipv4Interface))", action: nil, keyEquivalent: "")
            gw.isEnabled = false
            menu.addItem(gw)
        }

        menu.addItem(.separator())

        let wifiItem = NSMenuItem(title: "一键优先 Wi-Fi", action: #selector(handlePrioritizeWiFi), keyEquivalent: "1")
        wifiItem.target = self
        if let wifi = viewModel.wifiService {
            wifiItem.state = (viewModel.visibleServices.first?.id == wifi.id) ? .on : .off
        } else {
            wifiItem.isEnabled = false
        }
        menu.addItem(wifiItem)

        let wiredList = viewModel.wiredCandidates
        if !wiredList.isEmpty {
            let sectionTitle = NSMenuItem(title: "切换优先有线/USB 设备：", action: nil, keyEquivalent: "")
            sectionTitle.isEnabled = false
            menu.addItem(sectionTitle)

            for dev in wiredList {
                let tag = dev.config.isManagementOnly ? "仅内网" : dev.linkStatus.label
                let title = "  \(dev.displayName) [\(dev.device.isEmpty ? "-" : dev.device) · \(tag)]"
                let item = NSMenuItem(title: title, action: #selector(handlePrioritizeNamed(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = dev.serviceName
                item.state = (viewModel.visibleServices.first?.id == dev.id) ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "打开主窗口...", action: #selector(handleOpenWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "立即刷新状态", action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let loginItem = NSMenuItem(title: "开机自启", action: #selector(handleToggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = viewModel.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 NetPriority", action: #selector(handleQuit), keyEquivalent: "q")
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
