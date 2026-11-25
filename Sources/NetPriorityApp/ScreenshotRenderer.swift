import AppKit
import SwiftUI
import NetPriorityCore

@MainActor
enum ScreenshotRenderer {
    static func renderAll(to outputDir: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let specs: [(String, AppLanguage)] = [
            ("main-en.png", .en),
            ("main-zh.png", .zhHans)
        ]

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        for (filename, lang) in specs {
            let vm = AppViewModel.previewSample(language: lang)
            let resolved = lang.resolve()
            let hosting = NSHostingView(rootView: MainView(viewModel: vm))
            let size = NSSize(width: 840, height: 470)

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .aqua)
            window.title = L10n.windowTitle(resolved)
            window.contentView = hosting
            window.setContentSize(size)
            window.center()
            window.makeKeyAndOrderFront(nil)

            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()

            let bounds = hosting.bounds
            let scale = 2
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(bounds.width) * scale,
                pixelsHigh: Int(bounds.height) * scale,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else {
                continue
            }
            rep.size = bounds.size
            hosting.cacheDisplay(in: bounds, to: rep)

            if let png = rep.representation(using: .png, properties: [:]) {
                let targetURL = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
                try png.write(to: targetURL, options: .atomic)
            }
            window.orderOut(nil)
        }
    }
}
