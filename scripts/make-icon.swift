// Draws Panbar's app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024

/// A miniature of the menu bar strip: a Desktop badge and three app tiles,
/// the middle one focused, on a dark macOS-style rounded square.
func drawIcon(in context: NSGraphicsContext) {
    // Apple's icon grid: an 824pt body centered on a 1024pt canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    NSColor(srgbRed: 0.16, green: 0.17, blue: 0.22, alpha: 1).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(
        starting: NSColor(srgbRed: 0.24, green: 0.25, blue: 0.32, alpha: 1),
        ending: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.14, alpha: 1)
    )?.draw(in: shape, angle: -90)

    let tile: CGFloat = 150
    let gap: CGFloat = 36
    let radius: CGFloat = 36
    let rowWidth = tile * 4 + gap * 3 + 20
    var x = (canvas - rowWidth) / 2
    let y = (canvas - tile) / 2 + 20

    // Desktop badge with the number knocked out, as in the menu bar.
    let badge = NSRect(x: x, y: y, width: tile, height: tile)
    context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(roundedRect: badge, xRadius: radius, yRadius: radius).fill()
    let number = NSAttributedString(string: "1", attributes: [
        .font: NSFont.systemFont(ofSize: 112, weight: .bold),
        .foregroundColor: NSColor.black,
    ])
    let numberSize = number.size()
    context.compositingOperation = .destinationOut
    number.draw(at: NSPoint(x: badge.midX - numberSize.width / 2, y: badge.midY - numberSize.height / 2))
    context.compositingOperation = .sourceOver
    context.cgContext.endTransparencyLayer()
    x += tile + gap + 20

    let tiles: [(NSColor, NSColor, Bool)] = [
        (NSColor(srgbRed: 0.33, green: 0.56, blue: 1.00, alpha: 1),
         NSColor(srgbRed: 0.18, green: 0.32, blue: 0.85, alpha: 1), false),
        (NSColor(srgbRed: 0.72, green: 0.45, blue: 1.00, alpha: 1),
         NSColor(srgbRed: 0.45, green: 0.22, blue: 0.85, alpha: 1), true),
        (NSColor(srgbRed: 1.00, green: 0.62, blue: 0.30, alpha: 1),
         NSColor(srgbRed: 0.92, green: 0.36, blue: 0.22, alpha: 1), false),
    ]
    for (top, bottom, focused) in tiles {
        let rect = NSRect(x: x, y: y, width: tile, height: tile)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: -90)
        if focused {
            NSColor.white.withAlphaComponent(0.92).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: x + 24, y: y - 44, width: tile - 48, height: 18),
                xRadius: 9, yRadius: 9
            ).fill()
        } else {
            // Unfocused windows sit slightly back, like off-screen ones.
            NSColor.black.withAlphaComponent(0.18).setFill()
            path.fill()
        }
        x += tile + gap
    }
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawIcon(in: context)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

try fileManager.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try png(size: 512).write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
