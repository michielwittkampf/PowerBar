// Generates app/Resources/AppIcon.icns: the SF Symbol bolt.fill (the same bolt
// as in the menu bar) on a rounded square. It draws the symbol through AppKit,
// because the SF fonts have no bolt character to draw as text.
// Usage: swift app/make-icon.swift   (output is committed; rerun only to change it)
import AppKit

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let out = here.appendingPathComponent("Resources/AppIcon.icns")
let color = NSColor(srgbRed: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255, alpha: 1)

func master(_ size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // ~22% corner radius with a small inset, as in make-icon.py
    let inset = size * 0.06
    let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let square = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    color.setFill()
    square.fill()
    // subtle top-to-bottom sheen
    NSGradient(colors: [NSColor(white: 1, alpha: 0.15), NSColor(white: 1, alpha: 0)])!
        .draw(in: square, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold)
        .applying(.init(paletteColors: [NSColor(white: 1, alpha: 0.94)]))
    let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let b = bolt.size
    bolt.draw(in: NSRect(x: (size - b.width) / 2, y: (size - b.height) / 2, width: b.width, height: b.height))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(s)x\(s).png" : "icon_\(s)x\(s)@2x.png"
        let png = master(CGFloat(s * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: iconset.appendingPathComponent(name))
    }
}
try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! p.run()
p.waitUntilExit()
print("✓ \(out.path)")
