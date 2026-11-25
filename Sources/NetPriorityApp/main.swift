import AppKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let idx = args.firstIndex(of: "--render-screenshots"), idx + 1 < args.count {
        _ = NSApplication.shared
        do {
            try ScreenshotRenderer.renderAll(to: args[idx + 1])
            exit(0)
        } catch {
            fputs("Screenshot render failed: \(error)\n", stderr)
            exit(1)
        }
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
