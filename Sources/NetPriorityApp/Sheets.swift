import SwiftUI
import NetPriorityCore

struct AliasEditorSheet: View {
    let item: NetworkServiceItem
    let lang: ResolvedLanguage
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(item: NetworkServiceItem, lang: ResolvedLanguage, onSave: @escaping (String) -> Void) {
        self.item = item
        self.lang = lang
        self.onSave = onSave
        _text = State(initialValue: item.alias ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.aliasSheetTitle(lang))
                .font(.headline)

            Text(L10n.originalSystemName(item.serviceName, device: item.device, lang))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(L10n.aliasPlaceholder(lang), text: $text)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Text(L10n.aliasPresetsTitle(lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(L10n.aliasPresets(lang), id: \.self) { preset in
                    Button(preset) {
                        text = preset
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            HStack {
                Button(L10n.clearAliasBtn(lang)) {
                    onSave("")
                    dismiss()
                }
                .disabled((item.alias ?? "").isEmpty && text.isEmpty)

                Spacer()

                Button(L10n.cancelBtn(lang)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.saveBtn(lang)) {
                    onSave(text)
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

struct ManagementIPSheet: View {
    let item: NetworkServiceItem
    let lang: ResolvedLanguage
    let onConfirm: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ip: String
    @State private var mask: String
    @State private var validationError: String?

    init(item: NetworkServiceItem, lang: ResolvedLanguage, onConfirm: @escaping (String, String) -> Void) {
        self.item = item
        self.lang = lang
        self.onConfirm = onConfirm
        let defaultIP = Parsers.isValidIPv4(item.effectiveIPv4) ? item.effectiveIPv4 : "192.168.0.100"
        let defaultMask = Parsers.isValidIPv4(item.config.subnetMask) ? item.config.subnetMask : "255.255.255.0"
        _ip = State(initialValue: defaultIP)
        _mask = State(initialValue: defaultMask)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.mgmtSheetTitle(lang))
                .font(.headline)

            Text(L10n.mgmtSheetDesc(item.displayName, lang))
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text(L10n.ipv4AddressLabel(lang))
                        .frame(width: 104, alignment: .trailing)
                    TextField("192.168.0.100", text: $ip)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(L10n.subnetMaskLabel(lang))
                        .frame(width: 104, alignment: .trailing)
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
                Button(L10n.cancelBtn(lang)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.applyBtn(lang)) {
                    let cleanIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanMask = mask.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard Parsers.isValidIPv4(cleanIP) else {
                        validationError = L10n.invalidIPv4Error(lang)
                        return
                    }
                    guard Parsers.isValidIPv4(cleanMask) else {
                        validationError = L10n.invalidMaskError(lang)
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
        .frame(width: 450)
    }
}
