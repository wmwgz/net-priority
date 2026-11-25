import Foundation

public final class PreferencesStore {
    public static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard
    private let aliasesKey = "netpriority.serviceAliases"
    private let manualConfigsKey = "netpriority.savedManualConfigs"
    private let showHiddenKey = "netpriority.showHiddenServices"

    public init() {}

    public func loadAliases() -> [String: String] {
        defaults.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
    }

    public func saveAlias(_ alias: String, for serviceName: String) {
        var current = loadAliases()
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            current.removeValue(forKey: serviceName)
        } else {
            current[serviceName] = trimmed
        }
        defaults.set(current, forKey: aliasesKey)
    }

    public func loadManualConfig(for serviceName: String) -> SavedManualConfig? {
        guard let data = defaults.data(forKey: manualConfigsKey),
              let map = try? JSONDecoder().decode([String: SavedManualConfig].self, from: data) else {
            return nil
        }
        return map[serviceName]
    }

    public func saveManualConfig(_ config: SavedManualConfig, for serviceName: String) {
        var map: [String: SavedManualConfig] = [:]
        if let data = defaults.data(forKey: manualConfigsKey),
           let decoded = try? JSONDecoder().decode([String: SavedManualConfig].self, from: data) {
            map = decoded
        }
        map[serviceName] = config
        if let encoded = try? JSONEncoder().encode(map) {
            defaults.set(encoded, forKey: manualConfigsKey)
        }
    }

    public var showHiddenServices: Bool {
        get { defaults.bool(forKey: showHiddenKey) }
        set { defaults.set(newValue, forKey: showHiddenKey) }
    }
}

public enum NetworkManager {
    public static func loadSnapshot(aliases: [String: String], includeHidden: Bool) -> NetworkSnapshot {
        let orderResult = CommandRunner.run("/usr/sbin/networksetup", ["-listnetworkserviceorder"])
        let rawEntries = Parsers.parseServiceOrder(orderResult.stdout)

        let v4RouteRes = CommandRunner.run("/sbin/route", ["-n", "get", "default"])
        let v4Parsed = v4RouteRes.exitCode == 0 ? Parsers.parseRouteGet(v4RouteRes.stdout) : (interface: "", gateway: "")

        let v6RouteRes = CommandRunner.run("/sbin/route", ["-n", "get", "-inet6", "default"])
        let v6Parsed = v6RouteRes.exitCode == 0 ? Parsers.parseRouteGet(v6RouteRes.stdout) : (interface: "", gateway: "")

        let routeInfo = RouteInfo(
            ipv4Interface: v4Parsed.interface,
            ipv4Gateway: v4Parsed.gateway,
            ipv6Interface: v6Parsed.interface,
            ipv6Gateway: v6Parsed.gateway
        )

        var items = Array<NetworkServiceItem?>(repeating: nil, count: rawEntries.count)
        DispatchQueue.concurrentPerform(iterations: rawEntries.count) { idx in
            let entry = rawEntries[idx]
            let kind = Parsers.classifyService(
                serviceName: entry.serviceName,
                hardwarePort: entry.hardwarePort,
                device: entry.device
            )

            let shouldQueryDetails = includeHidden || (kind == .wifi || kind == .wired || kind == .usbModemOrPhone || kind == .bridge)
            var cfg = ServiceConfigInfo()
            if shouldQueryDetails {
                let infoRes = CommandRunner.run("/usr/sbin/networksetup", ["-getinfo", entry.serviceName])
                if infoRes.exitCode == 0 {
                    cfg = Parsers.parseServiceInfo(infoRes.stdout)
                }
            }

            var linkStatus: LinkStatus = entry.isEnabled ? .inactive : .disabled
            var liveIPv4 = ""
            var mediaSummary = ""

            if !entry.device.isEmpty && shouldQueryDetails {
                let ifRes = CommandRunner.run("/sbin/ifconfig", [entry.device])
                let parsedIf = Parsers.parseIfconfig(ifRes.stdout, exitCode: ifRes.exitCode)
                if entry.isEnabled {
                    linkStatus = parsedIf.status
                } else {
                    linkStatus = .disabled
                }
                liveIPv4 = parsedIf.ipv4
                mediaSummary = parsedIf.mediaSummary
            } else if entry.device.isEmpty && entry.isEnabled {
                linkStatus = .inactive
            }

            let isDefV4 = !entry.device.isEmpty && entry.device == routeInfo.ipv4Interface && entry.isEnabled
            let isDefV6 = !entry.device.isEmpty && entry.device == routeInfo.ipv6Interface && entry.isEnabled

            items[idx] = NetworkServiceItem(
                orderIndex: entry.orderIndex,
                serviceName: entry.serviceName,
                hardwarePort: entry.hardwarePort,
                device: entry.device,
                isEnabled: entry.isEnabled,
                kind: kind,
                linkStatus: linkStatus,
                liveIPv4: liveIPv4,
                mediaSummary: mediaSummary,
                config: cfg,
                isDefaultIPv4Route: isDefV4,
                isDefaultIPv6Route: isDefV6,
                alias: aliases[entry.serviceName]
            )
        }

        return NetworkSnapshot(services: items.compactMap { $0 }, routeInfo: routeInfo)
    }

    public static func setOrder(_ allServiceNames: [String]) throws {
        guard !allServiceNames.isEmpty else { return }
        try CommandRunner.runNetworkSetup(["-ordernetworkservices"] + allServiceNames)
    }

    public static func promoteService(_ serviceName: String, allServices: [String]) throws {
        let newOrder = Parsers.promoteToTop(allServices: allServices, target: serviceName)
        try setOrder(newOrder)
    }

    public static func setEnabled(_ serviceName: String, enabled: Bool) throws {
        try CommandRunner.runNetworkSetup(["-setnetworkserviceenabled", serviceName, enabled ? "on" : "off"])
    }

    public static func setManagementOnly(_ serviceName: String, ip: String, subnetMask: String) throws {
        guard Parsers.isValidIPv4(ip) else {
            throw NetworkManagerError.invalidInput("IPv4 地址格式无效：\(ip)")
        }
        guard Parsers.isValidIPv4(subnetMask) else {
            throw NetworkManagerError.invalidInput("子网掩码格式无效：\(subnetMask)")
        }
        try CommandRunner.runNetworkSetup(["-setmanual", serviceName, ip, subnetMask])
        try CommandRunner.runNetworkSetup(["-setv6off", serviceName])
    }

    public static func setDHCPInternet(_ serviceName: String) throws {
        try CommandRunner.runNetworkSetup(["-setdhcp", serviceName])
        try CommandRunner.runNetworkSetup(["-setv6automatic", serviceName])
    }
}

public enum LaunchAtLoginManager {
    public static let label = "com.gao.netpriority"

    public static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static func resolvedExecutablePath() -> String {
        let appExec = "/Applications/NetPriority.app/Contents/MacOS/NetPriority"
        if FileManager.default.isExecutableFile(atPath: appExec) {
            return appExec
        }
        return Bundle.main.executablePath ?? appExec
    }

    public static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            let launchAgentsDir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

            let execPath = resolvedExecutablePath()
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [execPath, "--background"],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } else {
            let uid = getuid()
            _ = CommandRunner.run("/bin/launchctl", ["bootout", "gui/\(uid)", plistURL.path])
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
        }
    }
}
