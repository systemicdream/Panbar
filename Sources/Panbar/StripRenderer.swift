import AppKit
import PanbarCore

/// Draws a workspace's windows as a row of app icons for the status item.
@MainActor
struct StripRenderer {
    var iconSize: CGFloat = 16
    var spacing: CGFloat = 4
    var height: CGFloat = 22
    var maxIcons = 12
    /// Alpha for windows Paneru has scrolled off-screen.
    var offscreenAlpha: CGFloat = 0.4

    let icons: IconProvider

    /// - Parameter label: drawn before the icons; the Desktop number.
    func image(for windows: [WindowState], label: String?) -> NSImage {
        let shown = Array(windows.prefix(maxIcons))
        let overflow = windows.count - shown.count
        let overflowText = overflow > 0 ? text("+\(overflow)") : nil
        let emptyText = windows.isEmpty ? text("–") : nil
        let labelText = label.map { text($0, weight: .bold, size: 12) }
        let labelGap: CGFloat = 6
        let badgeSize = labelText.map(Self.badgeSize(for:))

        var width = CGFloat(shown.count) * (iconSize + spacing) - (shown.isEmpty ? 0 : spacing)
        if let badgeSize {
            width += badgeSize.width + labelGap
        }
        for extra in [overflowText, emptyText].compactMap({ $0 }) {
            width += (width > 0 ? spacing : 0) + extra.size().width
        }

        let images = shown.map { icons.icon(for: $0.bundleID) }
        let size = NSSize(width: ceil(width), height: height)
        let iconSize = iconSize
        let spacing = spacing
        let offscreenAlpha = offscreenAlpha

        // The handler runs at draw time inside the button's appearance, so
        // dynamic colors resolve correctly in light and dark menu bars.
        return NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            if let labelText, let badgeSize {
                let rect = NSRect(
                    origin: NSPoint(x: 0, y: (size.height - badgeSize.height) / 2), size: badgeSize
                )
                Self.drawBadge(labelText, in: rect)
                x += badgeSize.width + labelGap
            }
            let iconY = (size.height - iconSize) / 2
            for (window, icon) in zip(shown, images) {
                let rect = NSRect(x: x, y: iconY, width: iconSize, height: iconSize)
                if window.focused {
                    NSColor.labelColor.withAlphaComponent(0.85).setFill()
                    NSBezierPath(
                        roundedRect: NSRect(x: x + 2, y: 0.5, width: iconSize - 4, height: 2),
                        xRadius: 1, yRadius: 1
                    ).fill()
                }
                icon.draw(
                    in: rect, from: .zero, operation: .sourceOver,
                    fraction: window.visible ? 1 : offscreenAlpha
                )
                x += iconSize + spacing
            }
            for extra in [overflowText, emptyText].compactMap({ $0 }) {
                let textSize = extra.size()
                extra.draw(at: NSPoint(x: x, y: (size.height - textSize.height) / 2))
                x += textSize.width + spacing
            }
            return true
        }
    }

    private static func badgeSize(for text: NSAttributedString) -> NSSize {
        let height: CGFloat = 17
        return NSSize(width: max(height, ceil(text.size().width) + 8), height: height)
    }

    /// A filled rounded square with the text knocked out of it, so the menu
    /// bar shows through the number, like the macOS Spaces indicator.
    private static func drawBadge(_ text: NSAttributedString, in rect: NSRect) {
        guard let context = NSGraphicsContext.current else { return }
        // The transparency layer keeps the knockout from punching through
        // anything already drawn beneath the badge.
        context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
        NSColor.labelColor.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        let textSize = text.size()
        context.compositingOperation = .destinationOut
        text.draw(at: NSPoint(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2
        ))
        context.compositingOperation = .sourceOver
        context.cgContext.endTransparencyLayer()
    }

    private func text(
        _ string: String, weight: NSFont.Weight = .regular, size: CGFloat? = nil
    ) -> NSAttributedString {
        let size = size ?? NSFont.menuBarFont(ofSize: 0).pointSize
        return NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.labelColor,
        ])
    }
}
