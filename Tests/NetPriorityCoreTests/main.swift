import Foundation
import NetPriorityCore

var assertionCount = 0
var failureCount = 0

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String = "", file: String = #fileID, line: Int = #line) {
    assertionCount += 1
    if actual != expected {
        failureCount += 1
        fputs("FAIL [\(file):\(line)] \(label): expected \(expected), got \(actual)\n", stderr)
    }
}

func checkTrue(_ cond: Bool, _ label: String = "", file: String = #fileID, line: Int = #line) {
    assertionCount += 1
    if !cond {
        failureCount += 1
        fputs("FAIL [\(file):\(line)] \(label): expected true\n", stderr)
    }
}

func testParseRealServiceOrder() {
    let sample = """
    An asterisk (*) denotes that a network service is disabled.
    (1) USB 10/100/1000 LAN
    (Hardware Port: USB 10/100/1000 LAN, Device: en5)

    (2) Wi-Fi
    (Hardware Port: Wi-Fi, Device: en0)

    (3) USB JTAG/serial debug unit 2
    (Hardware Port: USB JTAG/serial debug unit, Device: usbmodem113201)

    (4) J-Link
    (Hardware Port: J-Link, Device: usbmodem0007720207881)

    (*) 200806006809080000
    (Hardware Port: 200806006809080000, Device: en9)

    (8) Thunderbolt Bridge
    (Hardware Port: Thunderbolt Bridge, Device: bridge0)

    (9) iPhone USB
    (Hardware Port: iPhone USB, Device: en6)

    (10) Tailscale
    (Hardware Port: io.tailscale.ipn.macsys, Device: )
    """

    let entries = Parsers.parseServiceOrder(sample)
    checkEqual(entries.count, 8, "entries.count")
    checkEqual(entries[0].serviceName, "USB 10/100/1000 LAN", "entries[0].serviceName")
    checkEqual(entries[0].device, "en5", "entries[0].device")
    checkTrue(entries[0].isEnabled, "entries[0].isEnabled")
    checkEqual(entries[4].serviceName, "200806006809080000", "entries[4].serviceName")
    checkEqual(entries[4].device, "en9", "entries[4].device")
    checkTrue(!entries[4].isEnabled, "entries[4] disabled")
    checkEqual(entries[7].serviceName, "Tailscale", "entries[7].serviceName")
    checkEqual(entries[7].device, "", "entries[7].device")
    checkTrue(entries[7].isEnabled, "entries[7].isEnabled")
}

func testClassificationAndFiltering() {
    checkEqual(Parsers.classifyService(serviceName: "Wi-Fi", hardwarePort: "Wi-Fi", device: "en0"), .wifi)
    checkEqual(Parsers.classifyService(serviceName: "USB 10/100/1000 LAN", hardwarePort: "USB 10/100/1000 LAN", device: "en5"), .wired)
    checkEqual(Parsers.classifyService(serviceName: "200806006809080000", hardwarePort: "200806006809080000", device: "en9"), .wired)
    checkEqual(Parsers.classifyService(serviceName: "iPhone USB", hardwarePort: "iPhone USB", device: "en6"), .usbModemOrPhone)
    checkEqual(Parsers.classifyService(serviceName: "Unisoc Phone", hardwarePort: "Unisoc Phone", device: "en8"), .usbModemOrPhone)
    checkEqual(Parsers.classifyService(serviceName: "Thunderbolt Bridge", hardwarePort: "Thunderbolt Bridge", device: "bridge0"), .bridge)
    checkEqual(Parsers.classifyService(serviceName: "J-Link", hardwarePort: "J-Link", device: "usbmodem0007720207881"), .serialOrDebug)
    checkEqual(Parsers.classifyService(serviceName: "USB JTAG/serial debug unit", hardwarePort: "USB JTAG/serial debug unit", device: "usbmodem1101"), .serialOrDebug)
    checkEqual(Parsers.classifyService(serviceName: "Tailscale", hardwarePort: "io.tailscale.ipn.macsys", device: ""), .vpnOrVirtual)
}

func testParseServiceInfoVariants() {
    let dhcpOut = """
    DHCP Configuration
    IP address: 192.168.5.146
    Subnet mask: 255.255.255.0
    Router: 192.168.5.1
    Client ID: 
    IPv6: Automatic
    IPv6 IP address: none
    IPv6 Router: none
    Ethernet Address: 00:e0:4c:e6:f5:06
    """
    let dhcpInfo = Parsers.parseServiceInfo(dhcpOut)
    checkEqual(dhcpInfo.ipAddress, "192.168.5.146")
    checkEqual(dhcpInfo.router, "192.168.5.1")
    checkTrue(!dhcpInfo.isManagementOnly)

    let mgmtOut = """
    Manual Configuration
    IP address: 192.168.0.100
    Subnet mask: 255.255.255.0
    Router: (null)
    IPv6: Off
    Ethernet Address: (null)
    """
    let mgmtInfo = Parsers.parseServiceInfo(mgmtOut)
    checkEqual(mgmtInfo.ipAddress, "192.168.0.100")
    checkEqual(mgmtInfo.subnetMask, "255.255.255.0")
    checkEqual(mgmtInfo.router, "")
    checkEqual(mgmtInfo.ipv6Mode, "Off")
    checkTrue(mgmtInfo.isManagementOnly)
}

func testParseIfconfigAndRoute() {
    let ifOut = """
    en5: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    \tether 00:e0:4c:e6:f5:06
    \tinet 192.168.5.146 netmask 0xffffff00 broadcast 192.168.5.255
    \tmedia: autoselect (1000baseT <full-duplex>)
    \tstatus: active
    """
    let parsed = Parsers.parseIfconfig(ifOut, exitCode: 0)
    checkEqual(parsed.status, .active)
    checkEqual(parsed.ipv4, "192.168.5.146")
    checkEqual(parsed.mediaSummary, "1000M 全双工")

    let unplugged = Parsers.parseIfconfig("", exitCode: 1)
    checkEqual(unplugged.status, .unplugged)

    let routeOut = """
       route to: default
    destination: default
           mask: default
        gateway: 192.168.5.1
      interface: en0
    """
    let routeParsed = Parsers.parseRouteGet(routeOut)
    checkEqual(routeParsed.interface, "en0")
    checkEqual(routeParsed.gateway, "192.168.5.1")
}

func testOrderMergingPreservesHiddenServices() {
    let all = [
        "USB 10/100/1000 LAN",
        "Wi-Fi",
        "J-Link",
        "200806006809080000",
        "Tailscale",
        "iPhone USB"
    ]

    let promoted = Parsers.promoteToTop(allServices: all, target: "Wi-Fi")
    checkEqual(promoted, [
        "Wi-Fi",
        "USB 10/100/1000 LAN",
        "J-Link",
        "200806006809080000",
        "Tailscale",
        "iPhone USB"
    ])

    let reorderedVisible = [
        "iPhone USB",
        "Wi-Fi",
        "USB 10/100/1000 LAN",
        "200806006809080000"
    ]
    let merged = Parsers.mergeVisibleReorder(allServices: all, reorderedVisible: reorderedVisible)
    checkEqual(merged, [
        "iPhone USB",
        "Wi-Fi",
        "J-Link",
        "USB 10/100/1000 LAN",
        "Tailscale",
        "200806006809080000"
    ])
}

func testIPv4Validation() {
    checkTrue(Parsers.isValidIPv4("192.168.0.100"))
    checkTrue(Parsers.isValidIPv4("255.255.255.0"))
    checkTrue(!Parsers.isValidIPv4("192.168.0.256"))
    checkTrue(!Parsers.isValidIPv4("192.168.0"))
    checkTrue(!Parsers.isValidIPv4("abc.0.0.1"))
}

testParseRealServiceOrder()
testClassificationAndFiltering()
testParseServiceInfoVariants()
testParseIfconfigAndRoute()
testOrderMergingPreservesHiddenServices()
testIPv4Validation()

if failureCount > 0 {
    fputs("Tests failed: \(failureCount) of \(assertionCount) assertions failed.\n", stderr)
    exit(1)
}
print("All NetPriorityCore tests passed (\(assertionCount) assertions).")
