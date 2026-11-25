import SwiftUI
import NetPriorityCore

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    private var l: ResolvedLanguage { viewModel.lang }

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
        .frame(minWidth: 720, minHeight: 500)
        .sheet(item: $viewModel.editingAliasTarget) { target in
            AliasEditorSheet(item: target, lang: l) { newAlias in
                viewModel.saveAlias(for: target, alias: newAlias)
            }
        }
        .sheet(item: $viewModel.editingManagementTarget) { target in
            ManagementIPSheet(item: target, lang: l) { ip, mask in
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
                    Text(L10n.currentDefaultExit(l))
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
                            Text(L10n.gatewayPrefix(viewModel.routeInfo.ipv4Gateway, l))
                        }
                        if !exit.mediaSummary.isEmpty {
                            Text(exit.mediaSummary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(L10n.noDefaultRoute(l))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                wifiQuickSwitchButton
                wiredQuickSwitchButton
            }
        }
    }

    @ViewBuilder
    private var wifiQuickSwitchButton: some View {
        let active = viewModel.isWiFiPrimary
        Button {
            viewModel.prioritizeWiFi()
        } label: {
            Label(L10n.prioritizeWiFi(l), systemImage: "wifi")
                .font(.body.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(active ? Color.white : Color.primary)
                .background(
                    active ? Color.accentColor : Color.secondary.opacity(0.14),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy || viewModel.wifiService == nil)
    }

    @ViewBuilder
    private var wiredQuickSwitchButton: some View {
        let candidates = viewModel.wiredCandidates
        let active = viewModel.isWiredPrimary

        HStack(spacing: 0) {
            Button {
                viewModel.prioritizeWired()
            } label: {
                Label(L10n.prioritizeWired(l), systemImage: "cable.connector")
                    .font(.body.weight(.medium))
                    .padding(.leading, 14)
                    .padding(.trailing, candidates.count > 1 ? 10 : 14)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isBusy || candidates.isEmpty)

            if candidates.count > 1 {
                Rectangle()
                    .fill(active ? Color.white.opacity(0.35) : Color.primary.opacity(0.15))
                    .frame(width: 1, height: 16)

                Menu {
                    ForEach(candidates) { dev in
                        Button {
                            viewModel.prioritizeWired(serviceName: dev.serviceName)
                        } label: {
                            let devName = dev.device.isEmpty ? L10n.noDeviceInterface(l) : dev.device
                            Text("\(dev.displayName) (\(devName) · \(dev.linkStatus.localizedLabel(in: l)))")
                        }
                    }
                } label: {
                    Text("")
                }
                .menuStyle(.borderlessButton)
                .tint(active ? Color.white : Color.primary)
                .frame(width: 28, height: 30)
                .help(L10n.wiredSplitHelp(l))
                .disabled(viewModel.isBusy)
            }
        }
        .foregroundStyle(active ? Color.white : Color.primary)
        .background(
            active ? Color.accentColor : Color.secondary.opacity(0.14),
            in: Capsule(style: .continuous)
        )
    }

    private var heroExitColor: Color {
        guard let exit = viewModel.defaultExitService else { return .secondary }
        return exit.kind == .wifi ? .blue : .green
    }

    private var controlToolbar: some View {
        HStack(spacing: 12) {
            Text(L10n.dragHint(l))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Toggle(L10n.showHiddenToggle(count: viewModel.hiddenCount, l), isOn: $viewModel.showHiddenServices)
                .toggleStyle(.checkbox)
                .font(.caption)

            Toggle(L10n.launchAtLogin(l), isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)

            Menu {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        viewModel.appLanguage = option
                    } label: {
                        if viewModel.appLanguage == option {
                            Label(option.menuTitle(in: l), systemImage: "checkmark")
                        } else {
                            Text(option.menuTitle(in: l))
                        }
                    }
                }
            } label: {
                Label(viewModel.appLanguage.menuTitle(in: l), systemImage: "globe")
                    .font(.caption)
            }
            .menuStyle(.borderedButton)
            .controlSize(.small)
            .help(L10n.languageLabel(l))

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label(L10n.refresh(l), systemImage: "arrow.clockwise")
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
            Text(L10n.managementOrderBanner(item.displayName, l))
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
                    lang: l,
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
                Text(L10n.applyingChanges(l))
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
                Text(L10n.footerCount(visible: viewModel.visibleServices.count, hidden: viewModel.hiddenCount, showingHidden: viewModel.showHiddenServices, l))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let updated = viewModel.lastUpdated {
                Text(L10n.updatedAt(updated.formatted(date: .omitted, time: .standard), l))
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
    let lang: ResolvedLanguage
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
                .help(L10n.statusDotHelp(isEnabled: item.isEnabled, isDefault: item.isDefaultIPv4Route, link: item.linkStatus, lang))

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
                        badge(L10n.defaultExitBadge(lang), color: .green)
                    }

                    if item.config.isManagementOnly {
                        badge(L10n.modeManagementOnly(lang), color: .orange)
                    }

                    if !item.isEnabled {
                        badge(L10n.disabledBadge(lang), color: .red)
                    }
                }

                HStack(spacing: 10) {
                    Text(item.linkStatus.localizedLabel(in: lang))
                    if !item.effectiveIPv4.isEmpty {
                        Text("IP: \(item.effectiveIPv4)")
                    }
                    if !item.config.router.isEmpty {
                        Text(L10n.gatewayPrefix(item.config.router, lang))
                    } else if item.config.isManagementOnly {
                        Text(L10n.noGatewayIPv6(item.config.ipv6Mode, lang))
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
                    Button(item.config.isManagementOnly ? L10n.allowInternetBtn(lang) : L10n.managementOnlyBtn(lang)) {
                        onToggleManagement()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(item.config.isManagementOnly ? .orange : nil)
                    .help(item.config.isManagementOnly
                          ? L10n.allowInternetHelp(lang)
                          : L10n.managementOnlyHelp(lang))
                    .contextMenu {
                        Button(L10n.customManualIPMenu(lang)) {
                            onEditManagementIP()
                        }
                    }
                }

                if rank == 1 {
                    Text(L10n.highestPriorityBadge(lang))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Button(L10n.setPriorityBtn(lang)) {
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
                    .help(L10n.moveUpHelp(lang))

                    Button {
                        onMoveDown()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(rank >= totalVisible || isBusy)
                    .help(L10n.moveDownHelp(lang))
                }

                Button {
                    onEditAlias()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help(L10n.editAliasHelp(lang))

                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in onToggleEnabled() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(L10n.toggleEnableHelp(isEnabled: item.isEnabled, lang))
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
}
