import Foundation

public enum ResolvedLanguage: String, Equatable, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"
}

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"

    public var id: String { rawValue }

    public func resolve(preferredLanguages: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        switch self {
        case .zhHans: return .zhHans
        case .en: return .en
        case .ja: return .ja
        case .system:
            let first = (preferredLanguages.first ?? "en").lowercased()
            if first.hasPrefix("zh") { return .zhHans }
            if first.hasPrefix("ja") { return .ja }
            return .en
        }
    }

    public func menuTitle(in lang: ResolvedLanguage) -> String {
        switch self {
        case .system: return L10n.followSystem(lang)
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

public enum L10n {
    private static let lock = NSLock()
    private static var _appLanguage: AppLanguage = .system

    public static var appLanguage: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _appLanguage
        }
        set {
            lock.lock()
            _appLanguage = newValue
            lock.unlock()
        }
    }

    public static var resolved: ResolvedLanguage {
        appLanguage.resolve()
    }

    private static func t(_ lang: ResolvedLanguage, zh: String, en: String, ja: String) -> String {
        switch lang {
        case .zhHans: return zh
        case .en: return en
        case .ja: return ja
        }
    }

    // MARK: - Window & App
    public static func windowTitle(_ l: ResolvedLanguage) -> String {
        t(l, zh: "网卡优先级管理 (NetPriority)", en: "NetPriority — Network Priority Manager", ja: "NetPriority — ネットワーク優先度管理")
    }

    public static func followSystem(_ l: ResolvedLanguage) -> String {
        t(l, zh: "跟随系统", en: "Follow System", ja: "システムに従う")
    }

    public static func languageLabel(_ l: ResolvedLanguage) -> String {
        t(l, zh: "语言", en: "Language", ja: "言語")
    }

    // MARK: - Service Kinds & Link Status
    public static func serviceKind(_ kind: ServiceKind, _ l: ResolvedLanguage) -> String {
        switch kind {
        case .wifi: return t(l, zh: "无线 Wi-Fi", en: "Wi-Fi", ja: "Wi-Fi")
        case .wired: return t(l, zh: "有线网卡", en: "Wired Ethernet", ja: "有線イーサネット")
        case .usbModemOrPhone: return t(l, zh: "USB 共享/随身设备", en: "USB / Mobile Device", ja: "USB / モバイルデバイス")
        case .bridge: return t(l, zh: "雷雳网桥", en: "Thunderbolt Bridge", ja: "Thunderbolt ブリッジ")
        case .serialOrDebug: return t(l, zh: "调试串口", en: "Debug / Serial", ja: "デバッグ / シリアル")
        case .vpnOrVirtual: return t(l, zh: "虚拟/VPN", en: "Virtual / VPN", ja: "仮想 / VPN")
        }
    }

    public static func linkStatus(_ status: LinkStatus, _ l: ResolvedLanguage) -> String {
        switch status {
        case .active: return t(l, zh: "已连接", en: "Connected", ja: "接続済み")
        case .inactive: return t(l, zh: "未连接", en: "Disconnected", ja: "未接続")
        case .unplugged: return t(l, zh: "未接入", en: "Unplugged", ja: "未挿入")
        case .disabled: return t(l, zh: "已禁用", en: "Disabled", ja: "無効")
        }
    }

    public static func fullDuplex(_ l: ResolvedLanguage) -> String {
        t(l, zh: "全双工", en: "Full-Duplex", ja: "全二重")
    }

    public static func halfDuplex(_ l: ResolvedLanguage) -> String {
        t(l, zh: "半双工", en: "Half-Duplex", ja: "半二重")
    }

    public static func modeManagementOnly(_ l: ResolvedLanguage) -> String {
        t(l, zh: "仅内网管理", en: "Intranet Only", ja: "ローカル管理のみ")
    }

    public static func modeDHCP(_ l: ResolvedLanguage) -> String {
        t(l, zh: "DHCP 自动", en: "DHCP", ja: "DHCP")
    }

    public static func modeManualIP(_ l: ResolvedLanguage) -> String {
        t(l, zh: "手动 IP", en: "Manual IP", ja: "手動 IP")
    }

    public static func modeDefault(_ l: ResolvedLanguage) -> String {
        t(l, zh: "默认", en: "Default", ja: "デフォルト")
    }

    // MARK: - Hero Header & Toolbar
    public static func currentDefaultExit(_ l: ResolvedLanguage) -> String {
        t(l, zh: "当前默认上网出口", en: "Active Default Internet Route", ja: "現在のデフォルト接続先")
    }

    public static func noDefaultRoute(_ l: ResolvedLanguage) -> String {
        t(l, zh: "未检测到默认上网路由", en: "No default internet route detected", ja: "デフォルトルートが検出されません")
    }

    public static func gatewayPrefix(_ gw: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "网关: \(gw)", en: "Gateway: \(gw)", ja: "ゲートウェイ: \(gw)")
    }

    public static func prioritizeWiFi(_ l: ResolvedLanguage) -> String {
        t(l, zh: "优先 Wi-Fi", en: "Prefer Wi-Fi", ja: "Wi-Fi 優先")
    }

    public static func prioritizeWired(_ l: ResolvedLanguage) -> String {
        t(l, zh: "优先有线", en: "Prefer Wired", ja: "有線優先")
    }

    public static func noDeviceInterface(_ l: ResolvedLanguage) -> String {
        t(l, zh: "无接口", en: "No Interface", ja: "インターフェースなし")
    }

    public static func wiredSplitHelp(_ l: ResolvedLanguage) -> String {
        t(l,
          zh: "直接点击优先有线，点击右侧箭头可选择具体有线设备",
          en: "Click to prefer primary wired adapter, or open arrow menu to pick a specific device",
          ja: "クリックで有線を優先、右の矢印から特定のデバイスを選択できます")
    }

    public static func dragHint(_ l: ResolvedLanguage) -> String {
        t(l,
          zh: "拖拽网卡行或点击「设为优先」即可实时生效（第 1 位顺位最高）",
          en: "Drag rows or click \"Set Priority\" to apply immediately (#1 is highest)",
          ja: "行をドラッグまたは「優先にする」で即時反映（#1 が最優先）")
    }

    public static func showHiddenToggle(count: Int, _ l: ResolvedLanguage) -> String {
        t(l,
          zh: "显示串口/VPN (\(count))",
          en: "Show Serial/VPN (\(count))",
          ja: "シリアル/VPN表示 (\(count))")
    }

    public static func launchAtLogin(_ l: ResolvedLanguage) -> String {
        t(l, zh: "开机自启", en: "Launch at Login", ja: "ログイン時に起動")
    }

    public static func refresh(_ l: ResolvedLanguage) -> String {
        t(l, zh: "刷新", en: "Refresh", ja: "更新")
    }

    public static func managementOrderBanner(_ name: String, _ l: ResolvedLanguage) -> String {
        t(l,
          zh: "当前第 1 位「\(name)」处于仅内网管理模式（无默认网关），系统会自动顺延由下方下一个可用网卡负责上网。",
          en: "\"\(name)\" (#1) is in Intranet-Only mode (no gateway); macOS routes internet traffic via the next active adapter below.",
          ja: "#1 の「\(name)」はローカル管理のみ（ゲートウェイなし）のため、インターネット通信はその下の有効なアダプタを経由します。")
    }

    // MARK: - Service Row
    public static func defaultExitBadge(_ l: ResolvedLanguage) -> String {
        t(l, zh: "默认出口", en: "Default Route", ja: "デフォルト")
    }

    public static func disabledBadge(_ l: ResolvedLanguage) -> String {
        t(l, zh: "已禁用", en: "Disabled", ja: "無効")
    }

    public static func noGatewayIPv6(_ mode: String, _ l: ResolvedLanguage) -> String {
        let m = mode.isEmpty ? "Off" : mode
        return t(l,
                 zh: "无默认网关 · IPv6 \(m)",
                 en: "No Gateway · IPv6 \(m)",
                 ja: "ゲートウェイなし · IPv6 \(m)")
    }

    public static func allowInternetBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "允许上网", en: "Allow Internet", ja: "ネット許可")
    }

    public static func managementOnlyBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "仅内网", en: "Intranet Only", ja: "ローカルのみ")
    }

    public static func allowInternetHelp(_ l: ResolvedLanguage) -> String {
        t(l,
          zh: "恢复 DHCP 自动获取网关，允许电脑通过该设备上网",
          en: "Restore DHCP and automatic IPv6 to allow internet routing through this adapter",
          ja: "DHCP と IPv6 自動取得に戻し、このアダプタ経由の通信を許可します")
    }

    public static func managementOnlyHelp(_ l: ResolvedLanguage) -> String {
        t(l,
          zh: "设为手动 IP 且不配网关、关闭 IPv6，仅用于访问设备管理后台（不抢默认网）",
          en: "Set manual IP without a gateway and turn IPv6 off (admin/intranet access only, won't hijack default route)",
          ja: "ゲートウェイなしの手動 IP と IPv6 オフに設定し、管理画面などローカル通信専用にします")
    }

    public static func customManualIPMenu(_ l: ResolvedLanguage) -> String {
        t(l, zh: "自定义手动内网 IP...", en: "Custom Manual IP...", ja: "手動 IP をカスタマイズ...")
    }

    public static func highestPriorityBadge(_ l: ResolvedLanguage) -> String {
        t(l, zh: "最高优先", en: "Top Priority", ja: "最優先")
    }

    public static func setPriorityBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "设为优先", en: "Set Priority", ja: "優先にする")
    }

    public static func moveUpHelp(_ l: ResolvedLanguage) -> String {
        t(l, zh: "上移一位", en: "Move Up", ja: "上へ移動")
    }

    public static func moveDownHelp(_ l: ResolvedLanguage) -> String {
        t(l, zh: "下移一位", en: "Move Down", ja: "下へ移動")
    }

    public static func editAliasHelp(_ l: ResolvedLanguage) -> String {
        t(l, zh: "设置备注名", en: "Set Alias", ja: "エイリアスを設定")
    }

    public static func toggleEnableHelp(isEnabled: Bool, _ l: ResolvedLanguage) -> String {
        if isEnabled {
            return t(l, zh: "点击禁用此网卡", en: "Disable this network service", ja: "このサービスを無効にする")
        } else {
            return t(l, zh: "点击启用此网卡", en: "Enable this network service", ja: "このサービスを有効にする")
        }
    }

    public static func statusDotHelp(isEnabled: Bool, isDefault: Bool, link: LinkStatus, _ l: ResolvedLanguage) -> String {
        if !isEnabled { return t(l, zh: "网卡已禁用", en: "Service disabled", ja: "サービス無効") }
        if isDefault { return t(l, zh: "当前默认上网出口", en: "Active default route", ja: "現在のデフォルト出口") }
        if link == .active { return t(l, zh: "物理链路已连接", en: "Link active", ja: "リンク接続済み") }
        return t(l, zh: "未连接或未插线", en: "Disconnected or unplugged", ja: "未接続または未挿入")
    }

    // MARK: - Footer
    public static func applyingChanges(_ l: ResolvedLanguage) -> String {
        t(l, zh: "正在应用系统网络配置...", en: "Applying network configuration...", ja: "ネットワーク設定を適用中...")
    }

    public static func footerCount(visible: Int, hidden: Int, showingHidden: Bool, _ l: ResolvedLanguage) -> String {
        if showingHidden {
            return t(l,
                     zh: "共 \(visible) 个网络设备",
                     en: "\(visible) network services",
                     ja: "合計 \(visible) 個のサービス")
        }
        return t(l,
                 zh: "共 \(visible) 个网络设备（已自动过滤 \(hidden) 个调试串口/VPN 项）",
                 en: "\(visible) adapters (\(hidden) serial/VPN items hidden)",
                 ja: "\(visible) 個のアダプタ（シリアル/VPN \(hidden) 件を非表示）")
    }

    public static func updatedAt(_ timeStr: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "更新于 \(timeStr)", en: "Updated \(timeStr)", ja: "更新: \(timeStr)")
    }

    // MARK: - Sheets
    public static func aliasSheetTitle(_ l: ResolvedLanguage) -> String {
        t(l, zh: "设置设备备注名", en: "Set Device Alias", ja: "デバイスエイリアスを設定")
    }

    public static func originalSystemName(_ name: String, device: String, _ l: ResolvedLanguage) -> String {
        let devPart = device.isEmpty ? "" : " (\(device))"
        return t(l,
                 zh: "原系统名称：\(name)\(devPart)",
                 en: "System Name: \(name)\(devPart)",
                 ja: "システム名: \(name)\(devPart)")
    }

    public static func aliasPlaceholder(_ l: ResolvedLanguage) -> String {
        t(l,
          zh: "例如：随身WiFi、扩展坞网口、手机USB",
          en: "e.g. Pocket WiFi, Dock LAN, Phone USB",
          ja: "例: ポケットWiFi、ドック有線、スマホUSB")
    }

    public static func aliasPresetsTitle(_ l: ResolvedLanguage) -> String {
        t(l, zh: "常用建议：", en: "Presets:", ja: "候補:")
    }

    public static func aliasPresets(_ l: ResolvedLanguage) -> [String] {
        switch l {
        case .zhHans: return ["随身WiFi", "扩展坞有线", "手机USB", "公司内网"]
        case .en: return ["Pocket WiFi", "Dock Ethernet", "Phone USB", "Office LAN"]
        case .ja: return ["ポケットWiFi", "ドック有線", "スマホUSB", "社内LAN"]
        }
    }

    public static func clearAliasBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "清除备注", en: "Clear", ja: "クリア")
    }

    public static func cancelBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "取消", en: "Cancel", ja: "キャンセル")
    }

    public static func saveBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "保存", en: "Save", ja: "保存")
    }

    public static func applyBtn(_ l: ResolvedLanguage) -> String {
        t(l, zh: "应用", en: "Apply", ja: "適用")
    }

    public static func mgmtSheetTitle(_ l: ResolvedLanguage) -> String {
        t(l, zh: "配置「仅内网管理」静态 IP", en: "Configure Intranet-Only Static IP", ja: "ローカル管理専用 IP を設定")
    }

    public static func mgmtSheetDesc(_ name: String, _ l: ResolvedLanguage) -> String {
        t(l,
          zh: "将为「\(name)」设置手动 IP，不配置路由器网关并关闭 IPv6，确保仅用于访问内网设备（如 192.168.0.1），不会抢占默认上网路线。",
          en: "Assigns a manual IP to \"\(name)\" with no router gateway and IPv6 off, so it stays reachable for local management (e.g. 192.168.0.1) without hijacking internet routing.",
          ja: "「\(name)」にゲートウェイなしの手動 IP と IPv6 オフを設定し、管理画面（192.168.0.1 等）専用としてデフォルトルートを奪わないようにします。")
    }

    public static func ipv4AddressLabel(_ l: ResolvedLanguage) -> String {
        t(l, zh: "IPv4 地址", en: "IPv4 Address", ja: "IPv4 アドレス")
    }

    public static func subnetMaskLabel(_ l: ResolvedLanguage) -> String {
        t(l, zh: "子网掩码", en: "Subnet Mask", ja: "サブネットマスク")
    }

    public static func invalidIPv4Error(_ l: ResolvedLanguage) -> String {
        t(l, zh: "请输入合法的 IPv4 地址", en: "Please enter a valid IPv4 address", ja: "有効な IPv4 アドレスを入力してください")
    }

    public static func invalidMaskError(_ l: ResolvedLanguage) -> String {
        t(l, zh: "请输入合法的子网掩码", en: "Please enter a valid subnet mask", ja: "有効なサブネットマスクを入力してください")
    }

    // MARK: - Status & Errors
    public static func wifiNotFoundErr(_ l: ResolvedLanguage) -> String {
        t(l, zh: "未找到 Wi-Fi 网络服务", en: "Wi-Fi network service not found", ja: "Wi-Fi サービスが見つかりません")
    }

    public static func wiredNotFoundErr(_ l: ResolvedLanguage) -> String {
        t(l, zh: "未找到可用的有线/USB 网卡设备", en: "No wired or USB adapter found", ja: "利用可能な有線/USBアダプタが見つかりません")
    }

    public static func promotedSuccess(_ name: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "已将「\(name)」设为最高优先级", en: "Set \"\(name)\" as top priority", ja: "「\(name)」を最優先に設定しました")
    }

    public static func orderUpdatedSuccess(_ l: ResolvedLanguage) -> String {
        t(l, zh: "已更新网卡优先级顺序", en: "Updated service priority order", ja: "サービス優先順位を更新しました")
    }

    public static func movedStepSuccess(_ name: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "已调整「\(name)」顺位", en: "Reordered \"\(name)\"", ja: "「\(name)」の順位を変更しました")
    }

    public static func toggledEnabledSuccess(_ name: String, enabled: Bool, _ l: ResolvedLanguage) -> String {
        if enabled {
            return t(l, zh: "已启用「\(name)」", en: "Enabled \"\(name)\"", ja: "「\(name)」を有効にしました")
        }
        return t(l, zh: "已禁用「\(name)」", en: "Disabled \"\(name)\"", ja: "「\(name)」を無効にしました")
    }

    public static func dhcpRestoredSuccess(_ name: String, _ l: ResolvedLanguage) -> String {
        t(l,
          zh: "已将「\(name)」恢复为 DHCP 允许上网",
          en: "Restored \"\(name)\" to DHCP (internet enabled)",
          ja: "「\(name)」を DHCP（ネット接続許可）に戻しました")
    }

    public static func mgmtEnabledSuccess(_ name: String, ip: String, _ l: ResolvedLanguage) -> String {
        t(l,
          zh: "「\(name)」已切换为仅内网管理（\(ip)，无网关）",
          en: "\"\(name)\" switched to Intranet-Only (\(ip), no gateway)",
          ja: "「\(name)」をローカル管理のみ（\(ip)、ゲートウェイなし）に切り替えました")
    }

    public static func aliasClearedSuccess(_ name: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "已清除「\(name)」的备注", en: "Cleared alias for \"\(name)\"", ja: "「\(name)」のエイリアスを削除しました")
    }

    public static func aliasSavedSuccess(_ name: String, alias: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "已将「\(name)」备注为「\(alias)」", en: "Aliased \"\(name)\" as \"\(alias)\"", ja: "「\(name)」を「\(alias)」に設定しました")
    }

    public static func launchAtLoginSuccess(_ enabled: Bool, _ l: ResolvedLanguage) -> String {
        if enabled {
            return t(l,
                     zh: "已开启登录时静默启动到菜单栏",
                     en: "Enabled silent launch to menu bar at login",
                     ja: "ログイン時のメニューバー常駐起動を有効にしました")
        }
        return t(l, zh: "已关闭开机自启", en: "Disabled Launch at Login", ja: "ログイン時の起動を無効にしました")
    }

    public static func commandFailed(_ cmd: String, _ detail: String, _ l: ResolvedLanguage) -> String {
        t(l,
          zh: "执行系统网络命令失败（\(cmd)）：\(detail)",
          en: "System network command failed (\(cmd)): \(detail)",
          ja: "システムネットワークコマンド失敗（\(cmd)）: \(detail)")
    }

    public static func launchAgentFailed(_ msg: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "设置开机自启失败：\(msg)", en: "Failed to configure Launch at Login: \(msg)", ja: "自動起動の設定に失敗: \(msg)")
    }

    public static func invalidIPWithVal(_ ip: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "IPv4 地址格式无效：\(ip)", en: "Invalid IPv4 address: \(ip)", ja: "無効な IPv4 アドレス: \(ip)")
    }

    public static func invalidMaskWithVal(_ mask: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "子网掩码格式无效：\(mask)", en: "Invalid subnet mask: \(mask)", ja: "無効なサブネットマスク: \(mask)")
    }

    // MARK: - Menu Bar & Main Menu
    public static func menuBarNoExitShort(_ l: ResolvedLanguage) -> String {
        t(l, zh: "无出口", en: "Offline", ja: "未接続")
    }

    public static func menuBarNoIP(_ l: ResolvedLanguage) -> String {
        t(l, zh: "无 IP", en: "No IP", ja: "IP なし")
    }

    public static func menuBarCurrentExit(_ name: String, ip: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "当前出口：\(name)（\(ip)）", en: "Exit: \(name) (\(ip))", ja: "現在の接続先: \(name)（\(ip)）")
    }

    public static func menuBarNoDefaultExit(_ l: ResolvedLanguage) -> String {
        t(l, zh: "当前无默认上网出口", en: "No default internet route", ja: "デフォルト接続先なし")
    }

    public static func menuBarGateway(_ gw: String, iface: String, _ l: ResolvedLanguage) -> String {
        t(l, zh: "默认网关：\(gw) (\(iface))", en: "Gateway: \(gw) (\(iface))", ja: "ゲートウェイ: \(gw) (\(iface))")
    }

    public static func menuBarPreferWiFi(_ l: ResolvedLanguage) -> String {
        t(l, zh: "一键优先 Wi-Fi", en: "Prefer Wi-Fi", ja: "Wi-Fi を最優先にする")
    }

    public static func menuBarSwitchWiredHeader(_ l: ResolvedLanguage) -> String {
        t(l, zh: "切换优先有线/USB 设备：", en: "Prefer Wired / USB Adapter:", ja: "優先する有線/USBデバイス:")
    }

    public static func menuBarOpenWindow(_ l: ResolvedLanguage) -> String {
        t(l, zh: "打开主窗口...", en: "Open Main Window...", ja: "メインウィンドウを開く...")
    }

    public static func menuBarRefresh(_ l: ResolvedLanguage) -> String {
        t(l, zh: "立即刷新状态", en: "Refresh Now", ja: "今すぐ更新")
    }

    public static func menuBarQuit(_ l: ResolvedLanguage) -> String {
        t(l, zh: "退出 NetPriority", en: "Quit NetPriority", ja: "NetPriority を終了")
    }

    public static func mainMenuHide(_ l: ResolvedLanguage) -> String {
        t(l, zh: "隐藏网卡优先级管理", en: "Hide NetPriority", ja: "NetPriority を隠す")
    }

    public static func mainMenuEdit(_ l: ResolvedLanguage) -> String {
        t(l, zh: "编辑", en: "Edit", ja: "編集")
    }

    public static func mainMenuUndo(_ l: ResolvedLanguage) -> String {
        t(l, zh: "撤销", en: "Undo", ja: "取り消す")
    }

    public static func mainMenuRedo(_ l: ResolvedLanguage) -> String {
        t(l, zh: "重做", en: "Redo", ja: "やり直す")
    }

    public static func mainMenuCut(_ l: ResolvedLanguage) -> String {
        t(l, zh: "剪切", en: "Cut", ja: "カット")
    }

    public static func mainMenuCopy(_ l: ResolvedLanguage) -> String {
        t(l, zh: "拷贝", en: "Copy", ja: "コピー")
    }

    public static func mainMenuPaste(_ l: ResolvedLanguage) -> String {
        t(l, zh: "粘贴", en: "Paste", ja: "ペースト")
    }

    public static func mainMenuSelectAll(_ l: ResolvedLanguage) -> String {
        t(l, zh: "全选", en: "Select All", ja: "すべて選択")
    }

    public static func mainMenuWindow(_ l: ResolvedLanguage) -> String {
        t(l, zh: "窗口", en: "Window", ja: "ウインドウ")
    }

    public static func mainMenuCloseWindow(_ l: ResolvedLanguage) -> String {
        t(l, zh: "关闭窗口", en: "Close Window", ja: "ウインドウを閉じる")
    }

    public static func mainMenuMinimize(_ l: ResolvedLanguage) -> String {
        t(l, zh: "最小化", en: "Minimize", ja: "しまう")
    }
}
