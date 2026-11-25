import Foundation

public enum Parsers {
    private static let orderHeaderRegex = try! NSRegularExpression(pattern: #"^\((\*|\d+)\)\s+(.+)$"#)
    private static let hwPortRegex = try! NSRegularExpression(pattern: #"^\(Hardware Port:\s*(.+?),\s*Device:\s*(.*)\)$"#)

    public static func parseServiceOrder(_ output: String) -> [RawServiceEntry] {
        let lines = output.components(separatedBy: .newlines)
        var results: [RawServiceEntry] = []
        var pendingName: String?
        var pendingEnabled = true

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            if let m = orderHeaderRegex.firstMatch(in: line, range: fullRange) {
                let marker = nsLine.substring(with: m.range(at: 1))
                let name = nsLine.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                pendingEnabled = (marker != "*")
                pendingName = name
                continue
            }

            if let name = pendingName, let m = hwPortRegex.firstMatch(in: line, range: fullRange) {
                let hwPort = nsLine.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let device = nsLine.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                results.append(RawServiceEntry(
                    serviceName: name,
                    hardwarePort: hwPort,
                    device: device,
                    isEnabled: pendingEnabled,
                    orderIndex: results.count
                ))
                pendingName = nil
            }
        }
        return results
    }

    public static func classifyService(serviceName: String, hardwarePort: String, device: String) -> ServiceKind {
        let lowerName = serviceName.lowercased()
        let lowerPort = hardwarePort.lowercased()
        let lowerDev = device.lowercased()

        if lowerPort == "wi-fi" || lowerName == "wi-fi" || lowerPort.contains("airport") {
            return .wifi
        }
        if lowerDev.isEmpty {
            return .vpnOrVirtual
        }
        if lowerDev.hasPrefix("usbmodem") || lowerDev.hasPrefix("cu.") || lowerDev.hasPrefix("tty.")
            || lowerName.contains("jtag") || lowerPort.contains("jtag")
            || lowerName.contains("j-link") || lowerPort.contains("j-link")
            || lowerName.contains("serial") || lowerPort.contains("serial")
            || lowerName.contains("modem") || lowerName.contains("bluetooth") {
            return .serialOrDebug
        }
        if lowerDev.hasPrefix("bridge") || lowerPort.contains("thunderbolt bridge") {
            return .bridge
        }
        if lowerName.contains("iphone") || lowerPort.contains("iphone")
            || lowerName.contains("phone") || lowerPort.contains("phone")
            || lowerName.contains("android") || lowerPort.contains("android") {
            return .usbModemOrPhone
        }
        if lowerDev.hasPrefix("en") {
            return .wired
        }
        return .vpnOrVirtual
    }

    public static func parseServiceInfo(_ output: String) -> ServiceConfigInfo {
        var configType = ""
        var ipAddress = ""
        var subnetMask = ""
        var router = ""
        var ipv6Mode = ""
        var hardwareAddress = ""

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if line.hasSuffix("Configuration") && !line.contains(":") {
                configType = line
                continue
            }

            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = line[..<colonIdx].trimmingCharacters(in: .whitespaces).lowercased()
            let val = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
            let cleaned = (val == "(null)" || val == "none") ? "" : val

            switch key {
            case "ip address":
                ipAddress = cleaned
            case "subnet mask":
                subnetMask = cleaned
            case "router":
                router = cleaned
            case "ipv6":
                ipv6Mode = cleaned
            case "ethernet address", "wi-fi id":
                hardwareAddress = cleaned
            default:
                break
            }
        }

        return ServiceConfigInfo(
            configType: configType,
            ipAddress: ipAddress,
            subnetMask: subnetMask,
            router: router,
            ipv6Mode: ipv6Mode,
            hardwareAddress: hardwareAddress
        )
    }

    public static func parseIfconfig(_ output: String, exitCode: Int32) -> (status: LinkStatus, ipv4: String, mediaSummary: String) {
        if exitCode != 0 {
            return (.unplugged, "", "")
        }

        var status: LinkStatus = .inactive
        var ipv4 = ""
        var rawMedia = ""

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("status:") {
                let val = line.dropFirst("status:".count).trimmingCharacters(in: .whitespaces).lowercased()
                status = (val == "active") ? .active : .inactive
            } else if line.hasPrefix("inet ") {
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                if parts.count >= 2 {
                    let ip = String(parts[1])
                    if ip != "127.0.0.1" && ipv4.isEmpty {
                        ipv4 = ip
                    }
                }
            } else if line.hasPrefix("media:") {
                rawMedia = String(line.dropFirst("media:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        return (status, ipv4, formatMedia(rawMedia))
    }

    public static func formatMedia(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.isEmpty || lower.contains("(none)") || lower == "autoselect" {
            return ""
        }
        let duplex = lower.contains("full-duplex") ? "全双工" : (lower.contains("half-duplex") ? "半双工" : "")
        if lower.contains("10gbase") {
            return duplex.isEmpty ? "10G" : "10G \(duplex)"
        }
        if lower.contains("5000base") {
            return duplex.isEmpty ? "5G" : "5G \(duplex)"
        }
        if lower.contains("2500base") {
            return duplex.isEmpty ? "2.5G" : "2.5G \(duplex)"
        }
        if lower.contains("1000base") {
            return duplex.isEmpty ? "1000M" : "1000M \(duplex)"
        }
        if lower.contains("100base") {
            return duplex.isEmpty ? "100M" : "100M \(duplex)"
        }
        if lower.contains("10base") {
            return duplex.isEmpty ? "10M" : "10M \(duplex)"
        }
        return raw
    }

    public static func parseRouteGet(_ output: String) -> (interface: String, gateway: String) {
        var iface = ""
        var gw = ""
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("interface:") {
                iface = String(line.dropFirst("interface:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("gateway:") {
                gw = String(line.dropFirst("gateway:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return (iface, gw)
    }

    public static func promoteToTop(allServices: [String], target: String) -> [String] {
        guard allServices.contains(target) else { return allServices }
        var result = [target]
        for s in allServices where s != target {
            result.append(s)
        }
        return result
    }

    public static func mergeVisibleReorder(allServices: [String], reorderedVisible: [String]) -> [String] {
        let visibleSet = Set(reorderedVisible)
        var visibleIter = reorderedVisible.makeIterator()
        var merged: [String] = []
        merged.reserveCapacity(allServices.count)

        for service in allServices {
            if visibleSet.contains(service) {
                if let nextVisible = visibleIter.next() {
                    merged.append(nextVisible)
                }
            } else {
                merged.append(service)
            }
        }
        while let remaining = visibleIter.next() {
            if !merged.contains(remaining) {
                merged.append(remaining)
            }
        }
        return merged
    }

    public static func isValidIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        for part in parts {
            guard !part.isEmpty, let num = Int(part), num >= 0, num <= 255 else {
                return false
            }
        }
        return true
    }
}
