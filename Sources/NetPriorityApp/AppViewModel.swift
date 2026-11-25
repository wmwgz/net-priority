import Foundation
import SwiftUI
import NetPriorityCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var services: [NetworkServiceItem] = []
    @Published var routeInfo: RouteInfo = RouteInfo()
    @Published var showHiddenServices: Bool {
        didSet {
            PreferencesStore.shared.showHiddenServices = showHiddenServices
            Task { await refresh() }
        }
    }
    @Published var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled()
    @Published var isBusy: Bool = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    @Published var editingAliasTarget: NetworkServiceItem?
    @Published var editingManagementTarget: NetworkServiceItem?

    private var watcher: NetworkWatcher?
    private var clearToastTask: Task<Void, Never>?

    init() {
        self.showHiddenServices = PreferencesStore.shared.showHiddenServices
        let w = NetworkWatcher { [weak self] in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        self.watcher = w
        w.start()
        Task { await refresh() }
    }

    var visibleServices: [NetworkServiceItem] {
        if showHiddenServices {
            return services
        }
        return services.filter { $0.isNetworkAdapter }
    }

    var hiddenCount: Int {
        services.filter { !$0.isNetworkAdapter }.count
    }

    var wifiService: NetworkServiceItem? {
        services.first { $0.kind == .wifi }
    }

    var wiredCandidates: [NetworkServiceItem] {
        services.filter { $0.isWiredSwitchCandidate }
    }

    var defaultExitService: NetworkServiceItem? {
        let iface = routeInfo.ipv4Interface
        if !iface.isEmpty, let match = services.first(where: { $0.device == iface && $0.isEnabled }) {
            return match
        }
        return services.first(where: { $0.isNetworkAdapter && $0.isEnabled && $0.linkStatus == .active && !$0.config.isManagementOnly })
    }

    var primaryWiredTarget: NetworkServiceItem? {
        let candidates = wiredCandidates
        if let activeInternet = candidates.first(where: { $0.isEnabled && $0.linkStatus == .active && !$0.config.isManagementOnly }) {
            return activeInternet
        }
        if let active = candidates.first(where: { $0.isEnabled && $0.linkStatus == .active }) {
            return active
        }
        return candidates.first(where: { $0.isEnabled }) ?? candidates.first
    }

    var isWiFiPrimary: Bool {
        if let exit = defaultExitService {
            return exit.kind == .wifi
        }
        return visibleServices.first?.kind == .wifi
    }

    var isWiredPrimary: Bool {
        if let exit = defaultExitService {
            return exit.isWiredSwitchCandidate
        }
        return visibleServices.first?.isWiredSwitchCandidate == true
    }

    func refresh() async {
        let aliases = PreferencesStore.shared.loadAliases()
        let includeHidden = showHiddenServices
        let snapshot = await Task.detached(priority: .userInitiated) {
            NetworkManager.loadSnapshot(aliases: aliases, includeHidden: includeHidden)
        }.value
        self.services = snapshot.services
        self.routeInfo = snapshot.routeInfo
        self.launchAtLogin = LaunchAtLoginManager.isEnabled()
        self.lastUpdated = Date()
    }

    func prioritizeWiFi() {
        guard let wifi = wifiService else {
            showError("未找到 Wi-Fi 网络服务")
            return
        }
        promote(wifi)
    }

    func prioritizeWired(serviceName: String? = nil) {
        let target: NetworkServiceItem?
        if let serviceName {
            target = services.first { $0.serviceName == serviceName }
        } else {
            target = primaryWiredTarget
        }
        guard let target else {
            showError("未找到可用的有线/USB 网卡设备")
            return
        }
        promote(target)
    }

    func promote(_ item: NetworkServiceItem) {
        let allNames = services.map { $0.serviceName }
        runMutation(successMessage: "已将「\(item.displayName)」设为最高优先级") {
            if !item.isEnabled {
                try NetworkManager.setEnabled(item.serviceName, enabled: true)
            }
            try NetworkManager.promoteService(item.serviceName, allServices: allNames)
        }
    }

    func moveVisible(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = visibleServices
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let mergedOrder = Parsers.mergeVisibleReorder(
            allServices: services.map { $0.serviceName },
            reorderedVisible: reordered.map { $0.serviceName }
        )
        runMutation(successMessage: "已更新网卡优先级顺序") {
            try NetworkManager.setOrder(mergedOrder)
        }
    }

    func moveStep(_ item: NetworkServiceItem, delta: Int) {
        let vis = visibleServices
        guard let idx = vis.firstIndex(where: { $0.id == item.id }) else { return }
        let targetIdx = idx + delta
        guard targetIdx >= 0 && targetIdx < vis.count else { return }
        var reordered = vis
        let element = reordered.remove(at: idx)
        reordered.insert(element, at: targetIdx)
        let mergedOrder = Parsers.mergeVisibleReorder(
            allServices: services.map { $0.serviceName },
            reorderedVisible: reordered.map { $0.serviceName }
        )
        runMutation(successMessage: "已调整「\(item.displayName)」顺位") {
            try NetworkManager.setOrder(mergedOrder)
        }
    }

    func toggleEnabled(_ item: NetworkServiceItem) {
        let nextEnabled = !item.isEnabled
        runMutation(successMessage: "已\(nextEnabled ? "启用" : "禁用")「\(item.displayName)」") {
            try NetworkManager.setEnabled(item.serviceName, enabled: nextEnabled)
        }
    }

    func toggleManagementOnly(_ item: NetworkServiceItem) {
        if item.config.isManagementOnly {
            runMutation(successMessage: "已将「\(item.displayName)」恢复为 DHCP 允许上网") {
                try NetworkManager.setDHCPInternet(item.serviceName)
            }
            return
        }

        let liveOrCfgIP = item.effectiveIPv4
        if Parsers.isValidIPv4(liveOrCfgIP) {
            let mask = Parsers.isValidIPv4(item.config.subnetMask) ? item.config.subnetMask : "255.255.255.0"
            applyManagementOnly(item, ip: liveOrCfgIP, mask: mask)
            return
        }

        if let saved = PreferencesStore.shared.loadManualConfig(for: item.serviceName),
           Parsers.isValidIPv4(saved.ip), Parsers.isValidIPv4(saved.subnetMask) {
            applyManagementOnly(item, ip: saved.ip, mask: saved.subnetMask)
            return
        }

        editingManagementTarget = item
    }

    func applyManagementOnly(_ item: NetworkServiceItem, ip: String, mask: String) {
        PreferencesStore.shared.saveManualConfig(SavedManualConfig(ip: ip, subnetMask: mask), for: item.serviceName)
        runMutation(successMessage: "「\(item.displayName)」已切换为仅内网管理（\(ip)，无网关）") {
            try NetworkManager.setManagementOnly(item.serviceName, ip: ip, subnetMask: mask)
        }
    }

    func saveAlias(for item: NetworkServiceItem, alias: String) {
        PreferencesStore.shared.saveAlias(alias, for: item.serviceName)
        showStatus(alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                   ? "已清除「\(item.serviceName)」的备注"
                   : "已将「\(item.serviceName)」备注为「\(alias)」")
        Task { await refresh() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            self.launchAtLogin = LaunchAtLoginManager.isEnabled()
            showStatus(enabled ? "已开启登录时静默启动到菜单栏" : "已关闭开机自启")
        } catch {
            self.launchAtLogin = LaunchAtLoginManager.isEnabled()
            showError(error.localizedDescription)
        }
    }

    private func runMutation(successMessage: String, operation: @escaping @Sendable () throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try operation()
                }.value
                try? await Task.sleep(nanoseconds: 250_000_000)
                await refresh()
                showStatus(successMessage)
            } catch {
                showError(error.localizedDescription)
                await refresh()
            }
            isBusy = false
        }
    }

    private func showStatus(_ msg: String) {
        errorMessage = nil
        statusMessage = msg
        clearToastTask?.cancel()
        clearToastTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                statusMessage = nil
            }
        }
    }

    private func showError(_ msg: String) {
        statusMessage = nil
        errorMessage = msg
    }
}
