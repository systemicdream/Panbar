import AppKit

/// App icons keyed by bundle ID, cached for the life of the process.
///
/// Icons are trimmed to their visible bounds, because apps pad their icons
/// inconsistently: one that follows Apple's grid leaves a transparent margin,
/// a full-bleed one doesn't, and at 16pt that reads as a size difference.
@MainActor
final class IconProvider {
    private var cache: [String: NSImage] = [:]

    func icon(for bundleID: String) -> NSImage {
        if let cached = cache[bundleID] {
            return cached
        }
        let icon = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
        let trimmed = Self.trimmed(icon) ?? icon
        cache[bundleID] = trimmed
        return trimmed
    }

    /// Renders `icon` and crops it to the smallest centered square holding
    /// its opaque pixels. Faint pixels (drop shadows) don't count.
    private static func trimmed(_ icon: NSImage, pixels: Int = 128, alphaThreshold: UInt8 = 100) -> NSImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else { return nil }
        var minX = pixels, minY = pixels, maxX = -1, maxY = -1
        for y in 0..<pixels {
            for x in 0..<pixels where data[(y * pixels + x) * 4 + 3] > alphaThreshold {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        // Square up around the content's center so the aspect ratio survives.
        let side = max(maxX - minX, maxY - minY) + 1
        let originX = min(max((minX + maxX + 1) / 2 - side / 2, 0), pixels - side)
        let originY = min(max((minY + maxY + 1) / 2 - side / 2, 0), pixels - side)
        guard let cropped = rep.cgImage?.cropping(
            to: CGRect(x: originX, y: originY, width: side, height: side)
        ) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: side, height: side))
    }
}
