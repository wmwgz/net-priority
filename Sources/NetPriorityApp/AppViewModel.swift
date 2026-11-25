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
    @Published var appLanguage: AppLanguage {
        didSet {
            PreferencesStore.shared.appLanguage = appLanguage
            L10n.appLanguage = appLanguage
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
        let savedLang = PreferencesStore.shared.appLanguage
        self.appLanguage = savedLang
        L10n.appLanguage = savedLang
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

    private init(previewServices: [NetworkServiceItem], routeInfo: RouteInfo, language: AppLanguage) {
        self.appLanguage = language
        L10n.appLanguage = language
        self.showHiddenServices = false
        self.launchAtLogin = true
        self.services = previewServices
        self.routeInfo = routeInfo
        self.lastUpdated = Date()
    }

    static func previewSample(language: AppLanguage) -> AppViewModel {
        let l = language.resolve()
        let dockAlias = l == .zhHans ? "扩展坞千兆有线" : (l == .ja ? "ドック有線LAN" : "Dock Gigabit LAN")
        let pocketAlias = l == .zhHans ? "随身WiFi" : (l == .ja ? "ポケットWiFi" : "Pocket WiFi")
        let duplex = L10n.fullDuplex(l)

        let items = [
            NetworkServiceItem(
                orderIndex: 0,
                serviceName: "USB 10/100/1000 LAN",
                hardwarePort: "USB 10/100/1000 LAN",
                device: "en5",
                isEnabled: true,
                kind: .wired,
                linkStatus: .active,
                liveIPv4: "192.168.1.108",
                mediaSummary: "1000M \(duplex)",
                config: ServiceConfigInfo(configType: "DHCP Configuration", ipAddress: "192.168.1.108", subnetMask: "255.255.255.0", router: "192.168.1.1", ipv6Mode: "Automatic"),
                isDefaultIPv4Route: true,
                isDefaultIPv6Route: true,
                alias: dockAlias
            ),
            NetworkServiceItem(
                orderIndex: 1,
                serviceName: "Wi-Fi",
                hardwarePort: "Wi-Fi",
                device: "en0",
                isEnabled: true,
                kind: .wifi,
                linkStatus: .active,
                liveIPv4: "192.168.1.112",
                mediaSummary: "",
                config: ServiceConfigInfo(configType: "DHCP Configuration", ipAddress: "192.168.1.112", subnetMask: "255.255.255.0", router: "192.168.1.1", ipv6Mode: "Automatic"),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: nil
            ),
            NetworkServiceItem(
                orderIndex: 2,
                serviceName: "USB LTE Modem",
                hardwarePort: "USB LTE Modem",
                device: "en9",
                isEnabled: true,
                kind: .wired,
                linkStatus: .active,
                liveIPv4: "192.168.0.100",
                mediaSummary: "100M \(duplex)",
                config: ServiceConfigInfo(configType: "Manual Configuration", ipAddress: "192.168.0.100", subnetMask: "255.255.255.0", router: "", ipv6Mode: "Off"),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: pocketAlias
            ),
            NetworkServiceItem(
                orderIndex: 3,
                serviceName: "iPhone USB",
                hardwarePort: "iPhone USB",
                device: "en6",
                isEnabled: true,
                kind: .usbModemOrPhone,
                linkStatus: .unplugged,
                liveIPv4: "",
                mediaSummary: "",
                config: ServiceConfigInfo(configType: "DHCP Configuration"),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: nil
            ),
            NetworkServiceItem(
                orderIndex: 4,
                serviceName: "Thunderbolt Bridge",
                hardwarePort: "Thunderbolt Bridge",
                device: "bridge0",
                isEnabled: false,
                kind: .bridge,
                linkStatus: .disabled,
                liveIPv4: "",
                mediaSummary: "",
                config: ServiceConfigInfo(configType: "DHCP Configuration"),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: nil
            ),
            NetworkServiceItem(
                orderIndex: 5,
                serviceName: "J-Link",
                hardwarePort: "J-Link",
                device: "usbmodem00077201",
                isEnabled: true,
                kind: .serialOrDebug,
                linkStatus: .inactive,
                liveIPv4: "",
                mediaSummary: "",
                config: ServiceConfigInfo(),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: nil
            ),
            NetworkServiceItem(
                orderIndex: 6,
                serviceName: "USB JTAG/serial debug unit",
                hardwarePort: "USB JTAG/serial debug unit",
                device: "usbmodem1101",
                isEnabled: true,
                kind: .serialOrDebug,
                linkStatus: .inactive,
                liveIPv4: "",
                mediaSummary: "",
                config: ServiceConfigInfo(),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: nil
            ),
            NetworkServiceItem(
                orderIndex: 7,
                serviceName: "Tailscale",
                hardwarePort: "io.tailscale.ipn.macsys",
                device: "",
                isEnabled: true,
                kind: .vpnOrVirtual,
                linkStatus: .inactive,
                liveIPv4: "",
                mediaSummary: "",
                config: ServiceConfigInfo(),
                isDefaultIPv4Route: false,
                isDefaultIPv6Route: false,
                alias: nil
            )
        ]

        let route = RouteInfo(
            ipv4Interface: "en5",
            ipv4Gateway: "192.168.1.1",
            ipv6Interface: "en5",
            ipv6Gateway: "fe80::1"
        )
        return AppViewModel(previewServices: items, routeInfo: route, language: language)
    }

    var lang: ResolvedLanguage {
        appLanguage.resolve()
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
        let resolvedLang = lang
        let snapshot = await Task.detached(priority: .userInitiated) {
            NetworkManager.loadSnapshot(aliases: aliases, includeHidden: includeHidden, lang: resolvedLang)
        }.value
        self.services = snapshot.services
        self.routeInfo = snapshot.routeInfo
        self.launchAtLogin = LaunchAtLoginManager.isEnabled()
        self.lastUpdated = Date()
    }

    func prioritizeWiFi() {
        guard let wifi = wifiService else {
            showError(L10n.wifiNotFoundErr(lang))
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
            showError(L10n.wiredNotFoundErr(lang))
            return
        }
        promote(target)
    }

    func promote(_ item: NetworkServiceItem) {
        let allNames = services.map { $0.serviceName }
        runMutation(successMessage: L10n.promotedSuccess(item.displayName, lang)) {
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
        runMutation(successMessage: L10n.orderUpdatedSuccess(lang)) {
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
        runMutation(successMessage: L10n.movedStepSuccess(item.displayName, lang)) {
            try NetworkManager.setOrder(mergedOrder)
        }
    }

    func toggleEnabled(_ item: NetworkServiceItem) {
        let nextEnabled = !item.isEnabled
        runMutation(successMessage: L10n.toggledEnabledSuccess(item.displayName, enabled: nextEnabled, lang)) {
            try NetworkManager.setEnabled(item.serviceName, enabled: nextEnabled)
        }
    }

    func toggleManagementOnly(_ item: NetworkServiceItem) {
        if item.config.isManagementOnly {
            runMutation(successMessage: L10n.dhcpRestoredSuccess(item.displayName, lang)) {
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
        runMutation(successMessage: L10n.mgmtEnabledSuccess(item.displayName, ip: ip, lang)) {
            try NetworkManager.setManagementOnly(item.serviceName, ip: ip, subnetMask: mask)
        }
    }

    func saveAlias(for item: NetworkServiceItem, alias: String) {
        PreferencesStore.shared.saveAlias(alias, for: item.serviceName)
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        showStatus(trimmed.isEmpty
                   ? L10n.aliasClearedSuccess(item.serviceName, lang)
                   : L10n.aliasSavedSuccess(item.serviceName, alias: trimmed, lang))
        Task { await refresh() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            self.launchAtLogin = LaunchAtLoginManager.isEnabled()
            showStatus(L10n.launchAtLoginSuccess(enabled, lang))
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
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await self?.refresh()
                }
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
