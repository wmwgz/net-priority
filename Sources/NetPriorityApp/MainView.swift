import SwiftUI
import NetPriorityCore

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            heroHeader
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            controlToolbar
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

            Divider()

            if let first = viewModel.visibleServices.first, first.config.isManagementOnly {
                managementOrderNotice(first)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
            }

            serviceList

            Divider()

            footerBar
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(item: $viewModel.editingAliasTarget) { target in
            AliasEditorSheet(item: target) { newAlias in
                viewModel.saveAlias(for: target, alias: newAlias)
            }
        }
        .sheet(item: $viewModel.editingManagementTarget) { target in
            ManagementIPSheet(item: target) { ip, mask in
                viewModel.applyManagementOnly(target, ip: ip, mask: mask)
            }
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(heroExitColor.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: viewModel.defaultExitService?.kind.systemImage ?? "wifi.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(heroExitColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("当前默认上网出口")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !viewModel.routeInfo.ipv6Interface.isEmpty {
                        Text("IPv6: \(viewModel.routeInfo.ipv6Interface)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                if let exit = viewModel.defaultExitService {
                    HStack(spacing: 8) {
                        Text(exit.displayName)
                            .font(.title3.weight(.semibold))
                        if !exit.device.isEmpty {
                            Text(exit.device)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    HStack(spacing: 10) {
                        if !exit.effectiveIPv4.isEmpty {
                            Text("IP: \(exit.effectiveIPv4)")
                        }
                        if !viewModel.routeInfo.ipv4Gateway.isEmpty {
                            Text("网关: \(viewModel.routeInfo.ipv4Gateway)")
                        }
                        if !exit.mediaSummary.isEmpty {
                            Text(exit.mediaSummary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("未检测到默认上网路由")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    viewModel.prioritizeWiFi()
                } label: {
                    Label("优先 Wi-Fi", systemImage: "wifi")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isBusy || viewModel.wifiService == nil)

                wiredQuickSwitchButton
            }
        }
    }

    private var wiredQuickSwitchButton: some View {
        let candidates = viewModel.wiredCandidates
        return HStack(spacing: 1) {
            Button {
                viewModel.prioritizeWired()
            } label: {
                Label("优先有线", systemImage: "cable.connector")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isBusy || candidates.isEmpty)

            if candidates.count > 1 {
                Menu {
                    ForEach(candidates) { dev in
                        Button {
                            viewModel.prioritizeWired(serviceName: dev.serviceName)
                        } label: {
                            HStack {
                                Text(dev.displayName)
                                Text("(\(dev.device.isEmpty ? "无接口" : dev.device) · \(dev.linkStatus.label))")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24, height: 32)
                .disabled(viewModel.isBusy)
                .help("选择要设为最高优先级的具体有线设备")
            }
        }
    }

    private var heroExitColor: Color {
        guard let exit = viewModel.defaultExitService else { return .secondary }
        return exit.kind == .wifi ? .blue : .green
    }

    private var controlToolbar: some View {
        HStack(spacing: 14) {
            Text("拖拽网卡行或点击「设为优先」即可实时生效（第 1 位顺位最高）")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Toggle("显示串口/VPN (\(viewModel.hiddenCount))", isOn: $viewModel.showHiddenServices)
                .toggleStyle(.checkbox)
                .font(.caption)

            Toggle("开机自启", isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isBusy)
        }
    }

    private func managementOrderNotice(_ item: NetworkServiceItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text("当前第 1 位「\(item.displayName)」处于仅内网管理模式（无默认网关），系统会自动顺延由下方下一个可用网卡负责上网。")
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var serviceList: some View {
        List {
            ForEach(Array(viewModel.visibleServices.enumerated()), id: \.element.id) { index, item in
                ServiceRowView(
                    rank: index + 1,
                    totalVisible: viewModel.visibleServices.count,
                    item: item,
                    isBusy: viewModel.isBusy,
                    onPromote: { viewModel.promote(item) },
                    onMoveUp: { viewModel.moveStep(item, delta: -1) },
                    onMoveDown: { viewModel.moveStep(item, delta: 1) },
                    onToggleManagement: { viewModel.toggleManagementOnly(item) },
                    onEditManagementIP: { viewModel.editingManagementTarget = item },
                    onEditAlias: { viewModel.editingAliasTarget = item },
                    onToggleEnabled: { viewModel.toggleEnabled(item) }
                )
            }
            .onMove { offsets, dest in
                viewModel.moveVisible(fromOffsets: offsets, toOffset: dest)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var footerBar: some View {
        HStack(spacing: 10) {
            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.small)
                Text("正在应用系统网络配置...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let err = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let msg = viewModel.statusMessage {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.primary)
            } else {
                Text("共 \(viewModel.visibleServices.count) 个网络设备" + (viewModel.showHiddenServices ? "" : "（已自动过滤 \(viewModel.hiddenCount) 个调试串口/VPN 项）"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let updated = viewModel.lastUpdated {
                Text("更新于 \(updated.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct ServiceRowView: View {
    let rank: Int
    let totalVisible: Int
    let item: NetworkServiceItem
    let isBusy: Bool
    let onPromote: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onToggleManagement: () -> Void
    let onEditManagementIP: () -> Void
    let onEditAlias: () -> Void
    let onToggleEnabled: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(rank == 1 ? .white : .secondary)
                .frame(width: 28, height: 22)
                .background(
                    rank == 1 ? Color.accentColor : Color.secondary.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )

            Circle()
                .fill(statusDotColor)
                .frame(width: 9, height: 9)
                .help(statusHelp)

            Image(systemName: item.kind.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(item.isEnabled ? .primary : .tertiary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(item.isEnabled ? .primary : .secondary)

                    if item.hasCustomAlias {
                        Text(item.serviceName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !item.device.isEmpty {
                        Text(item.device)
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                    }

                    if item.isDefaultIPv4Route {
                        badge("默认出口", color: .green)
                    }

                    if item.config.isManagementOnly {
                        badge("仅内网管理", color: .orange)
                    }

                    if !item.isEnabled {
                        badge("已禁用", color: .red)
                    }
                }

                HStack(spacing: 10) {
                    Text(item.linkStatus.label)
                    if !item.effectiveIPv4.isEmpty {
                        Text("IP: \(item.effectiveIPv4)")
                    }
                    if !item.config.router.isEmpty {
                        Text("网关: \(item.config.router)")
                    } else if item.config.isManagementOnly {
                        Text("无默认网关 · IPv6 \(item.config.ipv6Mode.isEmpty ? "Off" : item.config.ipv6Mode)")
                    }
                    if !item.mediaSummary.isEmpty {
                        Text(item.mediaSummary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if item.supportsManagementOnly && item.isEnabled {
                    Button(item.config.isManagementOnly ? "允许上网" : "仅内网") {
                        onToggleManagement()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(item.config.isManagementOnly ? .orange : nil)
                    .help(item.config.isManagementOnly
                          ? "恢复 DHCP 自动获取网关，允许电脑通过该设备上网"
                          : "设为手动 IP 且不配网关、关闭 IPv6，仅用于访问设备管理后台（不抢默认网）")
                    .contextMenu {
                        Button("自定义手动内网 IP...") {
                            onEditManagementIP()
                        }
                    }
                }

                if rank == 1 {
                    Text("最高优先")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Button("设为优先") {
                        onPromote()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 2) {
                    Button {
                        onMoveUp()
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(rank <= 1 || isBusy)
                    .help("上移一位")

                    Button {
                        onMoveDown()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(rank >= totalVisible || isBusy)
                    .help("下移一位")
                }

                Button {
                    onEditAlias()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("设置中文备注名")

                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in onToggleEnabled() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(item.isEnabled ? "点击禁用此网卡" : "点击启用此网卡")
            }
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var statusDotColor: Color {
        if !item.isEnabled { return .red }
        if item.isDefaultIPv4Route { return .green }
        if item.linkStatus == .active { return .blue }
        return .gray.opacity(0.5)
    }

    private var statusHelp: String {
        if !item.isEnabled { return "网卡已禁用" }
        if item.isDefaultIPv4Route { return "当前默认上网出口" }
        if item.linkStatus == .active { return "物理链路已连接" }
        return "未连接或未插线"
    }
}
