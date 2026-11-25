import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outDir)
try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func renderIcon(px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(px)
    let margin = size * 0.08
    let rect = NSRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
    let radius = rect.width * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.11, green: 0.45, blue: 0.96, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.06, green: 0.22, blue: 0.68, alpha: 1.0)
    )
    gradient?.draw(in: path, angle: -65)

    NSColor.white.withAlphaComponent(0.22).setStroke()
    path.lineWidth = max(1.0, size * 0.015)
    path.stroke()

    if let sym = NSImage(systemSymbolName: "arrow.up.arrow.down.circle.fill", accessibilityDescription: nil) {
        let cfg = NSImage.SymbolConfiguration(pointSize: rect.width * 0.56, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        if let colored = sym.withSymbolConfiguration(cfg) {
            let symSize = colored.size
            let drawRect = NSRect(
                x: (size - symSize.width) / 2,
                y: (size - symSize.height) / 2,
                width: symSize.width,
                height: symSize.height
            )
            colored.draw(in: drawRect)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for (px, filename) in specs {
    if let data = renderIcon(px: px) {
        try data.write(to: URL(fileURLWithPath: "\(outDir)/\(filename)"))
    }
}
