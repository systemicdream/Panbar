import AppKit

/// App icons keyed by bundle ID, cached for the life of the process.
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
        cache[bundleID] = icon
        return icon
    }
}
