import SwiftUI
import NetPriorityCore

struct AliasEditorSheet: View {
    let item: NetworkServiceItem
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(item: NetworkServiceItem, onSave: @escaping (String) -> Void) {
        self.item = item
        self.onSave = onSave
        _text = State(initialValue: item.alias ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("设置设备备注名")
                .font(.headline)

            Text("原系统名称：\(item.serviceName)" + (item.device.isEmpty ? "" : "（\(item.device)）"))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("例如：随身WiFi、扩展坞网口、手机USB", text: $text)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Text("常用建议：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(["随身WiFi", "扩展坞有线", "手机USB", "公司内网"], id: \.self) { preset in
                    Button(preset) {
                        text = preset
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            HStack {
                Button("清除备注") {
                    onSave("")
                    dismiss()
                }
                .disabled((item.alias ?? "").isEmpty && text.isEmpty)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    onSave(text)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

struct ManagementIPSheet: View {
    let item: NetworkServiceItem
    let onConfirm: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ip: String
    @State private var mask: String
    @State private var validationError: String?

    init(item: NetworkServiceItem, onConfirm: @escaping (String, String) -> Void) {
        self.item = item
        self.onConfirm = onConfirm
        let defaultIP = Parsers.isValidIPv4(item.effectiveIPv4) ? item.effectiveIPv4 : "192.168.0.100"
        let defaultMask = Parsers.isValidIPv4(item.config.subnetMask) ? item.config.subnetMask : "255.255.255.0"
        _ip = State(initialValue: defaultIP)
        _mask = State(initialValue: defaultMask)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("配置「仅内网管理」静态 IP")
                .font(.headline)

            Text("将为「\(item.displayName)」设置手动 IP，不配置路由器网关并关闭 IPv6，确保仅用于访问内网设备（如 192.168.0.1），不会抢占默认上网路线。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("IPv4 地址")
                        .frame(width: 72, alignment: .trailing)
                    TextField("192.168.0.100", text: $ip)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("子网掩码")
                        .frame(width: 72, alignment: .trailing)
                    TextField("255.255.255.0", text: $mask)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("应用") {
                    let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanMask = mask.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard Parsers.isValidIPv4(cleanIP) else {
                        validationError = "请输入合法的 IPv4 地址"
                        return
                    }
                    guard Parsers.isValidIPv4(cleanMask) else {
                        validationError = "请输入合法的子网掩码"
                        return
                    }
                    onConfirm(cleanIP, cleanMask)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
