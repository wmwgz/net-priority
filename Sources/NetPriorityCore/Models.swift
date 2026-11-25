import Foundation

public enum ServiceKind: String, Codable, Equatable, Hashable {
    case wifi
    case wired
    case usbModemOrPhone
    case bridge
    case serialOrDebug
    case vpnOrVirtual

    public var label: String {
        switch self {
        case .wifi: return "无线 Wi-Fi"
        case .wired: return "有线网卡"
        case .usbModemOrPhone: return "USB 共享/随身设备"
        case .bridge: return "雷雳网桥"
        case .serialOrDebug: return "调试串口"
        case .vpnOrVirtual: return "虚拟/VPN"
        }
    }

    public var systemImage: String {
        switch self {
        case .wifi: return "wifi"
        case .wired: return "cable.connector"
        case .usbModemOrPhone: return "iphone.gen3"
        case .bridge: return "bolt.horizontal.circle"
        case .serialOrDebug: return "cpu"
        case .vpnOrVirtual: return "network"
        }
    }
}

public enum LinkStatus: String, Codable, Equatable, Hashable {
    case active
    case inactive
    case unplugged
    case disabled

    public var label: String {
        switch self {
        case .active: return "已连接"
        case .inactive: return "未连接"
        case .unplugged: return "未接入"
        case .disabled: return "已禁用"
        }
    }
}

public struct RawServiceEntry: Equatable, Hashable {
    public let serviceName: String
    public let hardwarePort: String
    public let device: String
    public let isEnabled: Bool
    public let orderIndex: Int

    public init(serviceName: String, hardwarePort: String, device: String, isEnabled: Bool, orderIndex: Int) {
        self.serviceName = serviceName
        self.hardwarePort = hardwarePort
        self.device = device
        self.isEnabled = isEnabled
        self.orderIndex = orderIndex
    }
}

public struct ServiceConfigInfo: Equatable, Hashable {
    public let configType: String
    public let ipAddress: String
    public let subnetMask: String
    public let router: String
    public let ipv6Mode: String
    public let hardwareAddress: String

    public init(
        configType: String = "",
        ipAddress: String = "",
        subnetMask: String = "",
        router: String = "",
        ipv6Mode: String = "",
        hardwareAddress: String = ""
    ) {
        self.configType = configType
        self.ipAddress = ipAddress
        self.subnetMask = subnetMask
        self.router = router
        self.ipv6Mode = ipv6Mode
        self.hardwareAddress = hardwareAddress
    }

    public var isManagementOnly: Bool {
        let isManual = configType.localizedCaseInsensitiveContains("Manual")
        let noRouter = router.isEmpty || router == "(null)"
        let hasIP = !ipAddress.isEmpty && ipAddress != "(null)"
        return isManual && noRouter && hasIP
    }

    public var modeLabel: String {
        if isManagementOnly {
            return "仅内网管理"
        }
        if configType.localizedCaseInsensitiveContains("DHCP") {
            return "DHCP 自动"
        }
        if configType.localizedCaseInsensitiveContains("Manual") {
            return "手动 IP"
        }
        return configType.isEmpty ? "默认" : configType
    }
}

public struct NetworkServiceItem: Identifiable, Equatable, Hashable {
    public var id: String { serviceName }
    public let orderIndex: Int
    public let serviceName: String
    public let hardwarePort: String
    public let device: String
    public let isEnabled: Bool
    public let kind: ServiceKind
    public let linkStatus: LinkStatus
    public let liveIPv4: String
    public let mediaSummary: String
    public let config: ServiceConfigInfo
    public let isDefaultIPv4Route: Bool
    public let isDefaultIPv6Route: Bool
    public let alias: String?

    public init(
        orderIndex: Int,
        serviceName: String,
        hardwarePort: String,
        device: String,
        isEnabled: Bool,
        kind: ServiceKind,
        linkStatus: LinkStatus,
        liveIPv4: String,
        mediaSummary: String,
        config: ServiceConfigInfo,
        isDefaultIPv4Route: Bool,
        isDefaultIPv6Route: Bool,
        alias: String?
    ) {
        self.orderIndex = orderIndex
        self.serviceName = serviceName
        self.hardwarePort = hardwarePort
        self.device = device
        self.isEnabled = isEnabled
        self.kind = kind
        self.linkStatus = linkStatus
        self.liveIPv4 = liveIPv4
        self.mediaSummary = mediaSummary
        self.config = config
        self.isDefaultIPv4Route = isDefaultIPv4Route
        self.isDefaultIPv6Route = isDefaultIPv6Route
        self.alias = alias
    }

    public var displayName: String {
        if let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines), !alias.isEmpty {
            return alias
        }
        return serviceName
    }

    public var hasCustomAlias: Bool {
        if let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines), !alias.isEmpty {
            return true
        }
        return false
    }

    public var isNetworkAdapter: Bool {
        kind == .wifi || kind == .wired || kind == .usbModemOrPhone || kind == .bridge
    }

    public var isWiredSwitchCandidate: Bool {
        kind == .wired || kind == .usbModemOrPhone
    }

    public var supportsManagementOnly: Bool {
        isNetworkAdapter
    }

    public var effectiveIPv4: String {
        if !liveIPv4.isEmpty { return liveIPv4 }
        if !config.ipAddress.isEmpty && config.ipAddress != "(null)" { return config.ipAddress }
        return ""
    }
}

public struct RouteInfo: Equatable {
    public let ipv4Interface: String
    public let ipv4Gateway: String
    public let ipv6Interface: String
    public let ipv6Gateway: String

    public init(
        ipv4Interface: String = "",
        ipv4Gateway: String = "",
        ipv6Interface: String = "",
        ipv6Gateway: String = ""
    ) {
        self.ipv4Interface = ipv4Interface
        self.ipv4Gateway = ipv4Gateway
        self.ipv6Interface = ipv6Interface
        self.ipv6Gateway = ipv6Gateway
    }
}

public struct NetworkSnapshot: Equatable {
    public let services: [NetworkServiceItem]
    public let routeInfo: RouteInfo

    public init(services: [NetworkServiceItem], routeInfo: RouteInfo) {
        self.services = services
        self.routeInfo = routeInfo
    }
}

public struct SavedManualConfig: Codable, Equatable {
    public let ip: String
    public let subnetMask: String

    public init(ip: String, subnetMask: String) {
        self.ip = ip
        self.subnetMask = subnetMask
    }
}

public enum NetworkManagerError: LocalizedError {
    case commandFailed(command: String, detail: String)
    case invalidInput(String)
    case launchAgentFailed(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let cmd, let detail):
            return "执行系统网络命令失败（\(cmd)）：\(detail)"
        case .invalidInput(let msg):
            return msg
        case .launchAgentFailed(let msg):
            return "设置开机自启失败：\(msg)"
        }
    }
}
