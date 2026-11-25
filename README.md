# NetPriority

English | [简体中文](README_CN.md)

A lightweight native macOS SwiftUI + AppKit utility to inspect and switch network interface priority (Wi-Fi vs. specific wired / USB Ethernet / mobile tethering devices), configure **Intranet-Only (no default gateway)** adapters, and monitor the active internet exit live from the menu bar.

## Why NetPriority?

- **Multiple wired/USB adapters**: Distinguish between dock Gigabit Ethernet, portable USB Wi-Fi dongles, phone USB tethering, and Thunderbolt Bridge—promote any exact adapter to `#1` instead of a blind Wi-Fi/Ethernet toggle.
- **One-click "Intranet Only" mode**: Connect to an admin interface (e.g. a portable Wi-Fi router at `192.168.0.1` or an embedded AP over Wi-Fi) with a manual IP, **no router gateway**, and **IPv6 off**, so you can reach its local web UI without hijacking your default internet connection.
- **No noisy debug ports**: Automatically hides `J-Link`, `USB JTAG` serial modems, and virtual VPN extensions unless you toggle them visible—while always preserving their service order under the hood when reordering.
- **Live Menu Bar & Window**: Shows your current active exit, IPv4, gateway, link speed, and updates immediately on hotplug or route changes via `SCDynamicStore`.
- **Multi-Language UI**: Supports **Follow System**, **English**, **简体中文**, and **日本語** with instant live switching (no restart required).

## Features

- Main window + persistent menu bar status item (`--background` supported for Launch at Login)
- One-click **Prefer Wi-Fi** / **Prefer Wired** (with split menu to pick a specific wired adapter)
- Drag-and-drop and step buttons (`↑` / `↓`) for full priority ordering
- Per-adapter **Enable / Disable** toggle
- Per-adapter **Intranet Only / Allow Internet (DHCP)** toggle (available on both wired and Wi-Fi adapters; right-click to customize manual IP/mask)
- Custom aliases stored locally (e.g. rename `200806006809080000` to `Pocket WiFi`)
- Single-instance launch protection & native macOS keyboard shortcuts

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ (Xcode or Apple Command Line Tools)

## Build & Install

```bash
git clone https://github.com/<your-username>/net-priority.git
cd net-priority
swift run NetPrioritySelfTest
./scripts/build_app.sh
```

`build_app.sh` builds a release binary, generates the `.icns` icon, ad-hoc signs `NetPriority.app`, and installs it to `/Applications/NetPriority.app` (or `~/Applications/NetPriority.app` if `/Applications` is not writable).

### First Launch Note (Unsigned / Ad-hoc Signed Build)

If you download a prebuilt release binary without Apple Developer notarization and macOS Gatekeeper blocks it, clear the quarantine attribute once:

```bash
xattr -cr /Applications/NetPriority.app
```

## License

[MIT](LICENSE)
