import AppKit
import PanbarCore

/// Draws a workspace's windows as a row of app icons for the status item.
@MainActor
struct StripRenderer {
    /// Desktop badge and app icons share one tile shape so they line up.
    var tileSize: CGFloat = 17
    var cornerRadius: CGFloat = 4
    var spacing: CGFloat = 4
    var height: CGFloat = 24
    /// Upper bound on icons when there's no width budget (no notch).
    var maxIcons = 12
    /// Alpha for windows Paneru has scrolled off-screen.
    var offscreenAlpha: CGFloat = 0.4
    var labelGap: CGFloat = 6

    let icons: IconProvider

    private enum Element {
        case badge(NSAttributedString, NSSize)
        case text(NSAttributedString)
        case icon(WindowState, NSImage)
    }

    /// - Parameters:
    ///   - label: drawn before the icons as a badge; the Desktop number.
    ///   - maxWidth: the widest the image may be. When the strip doesn't fit,
    ///     it's cut to a run centered on the focused window, with counts of
    ///     the hidden windows at either end.
    func image(for windows: [WindowState], label: String?, maxWidth: CGFloat?) -> NSImage {
        let elements = layout(windows, label: label, maxWidth: maxWidth)
        let size = NSSize(width: ceil(width(of: elements)), height: height)
        let tileSize = tileSize
        let cornerRadius = cornerRadius
        let spacing = spacing
        let labelGap = labelGap
        let offscreenAlpha = offscreenAlpha

        // The handler runs at draw time inside the button's appearance, so
        // dynamic colors resolve correctly in light and dark menu bars.
        return NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            for element in elements {
                switch element {
                case .badge(let text, let badgeSize):
                    let rect = NSRect(
                        origin: NSPoint(x: x, y: (size.height - badgeSize.height) / 2), size: badgeSize
                    )
                    Self.drawBadge(text, in: rect, cornerRadius: cornerRadius)
                    x += badgeSize.width + labelGap
                case .text(let text):
                    let textSize = text.size()
                    text.draw(at: NSPoint(x: x, y: (size.height - textSize.height) / 2))
                    x += textSize.width + spacing
                case .icon(let window, let icon):
                    let rect = NSRect(x: x, y: (size.height - tileSize) / 2, width: tileSize, height: tileSize)
                    if window.focused {
                        NSColor.labelColor.withAlphaComponent(0.85).setFill()
                        NSBezierPath(
                            roundedRect: NSRect(x: x + 2, y: 0, width: tileSize - 4, height: 2),
                            xRadius: 1, yRadius: 1
                        ).fill()
                    }
                    Self.drawIcon(
                        icon, in: rect, cornerRadius: cornerRadius,
                        alpha: window.visible ? 1 : offscreenAlpha
                    )
                    x += tileSize + spacing
                }
            }
            return true
        }
    }

    /// Picks the largest run of icons around the anchor that fits `maxWidth`.
    private func layout(_ windows: [WindowState], label: String?, maxWidth: CGFloat?) -> [Element] {
        var leading: [Element] = []
        if let label {
            let text = text(label, weight: .bold, size: 12)
            leading.append(.badge(text, badgeSize(for: text)))
        }
        if windows.isEmpty {
            return leading + [.text(text("–"))]
        }

        let anchor = StripWindowing.anchor(in: windows)
        func elements(capacity: Int) -> [Element] {
            let range = StripWindowing.range(count: windows.count, anchor: anchor, capacity: capacity)
            var result = leading
            if range.lowerBound > 0 {
                result.append(.text(overflowText(range.lowerBound)))
            }
            result += windows[range].map { .icon($0, icons.icon(for: $0.bundleID)) }
            if range.upperBound < windows.count {
                result.append(.text(overflowText(windows.count - range.upperBound)))
            }
            return result
        }

        let most = min(windows.count, maxIcons)
        guard let maxWidth else { return elements(capacity: most) }
        for capacity in stride(from: most, to: 1, by: -1) {
            let candidate = elements(capacity: capacity)
            if width(of: candidate) <= maxWidth {
                return candidate
            }
        }
        // Always keep the focused window, even if it overruns the budget.
        return elements(capacity: 1)
    }

    private func width(of elements: [Element]) -> CGFloat {
        var width: CGFloat = 0
        for (index, element) in elements.enumerated() {
            let isLast = index == elements.count - 1
            switch element {
            case .badge(_, let size): width += size.width + (isLast ? 0 : labelGap)
            case .text(let text): width += text.size().width + (isLast ? 0 : spacing)
            case .icon: width += tileSize + (isLast ? 0 : spacing)
            }
        }
        return width
    }

    private func overflowText(_ count: Int) -> NSAttributedString {
        NSAttributedString(string: "+\(count)", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    private func badgeSize(for text: NSAttributedString) -> NSSize {
        NSSize(width: max(tileSize, ceil(text.size().width) + 8), height: tileSize)
    }

    /// Clips the icon to the badge's rounded square. App icons have rounder,
    /// continuous corners, so the icon is drawn slightly oversized to fill the
    /// clip's corners instead of leaving gaps there.
    private static func drawIcon(_ icon: NSImage, in rect: NSRect, cornerRadius: CGFloat, alpha: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
        icon.draw(
            in: rect.insetBy(dx: -0.6, dy: -0.6), from: .zero, operation: .sourceOver, fraction: alpha
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    /// A filled rounded square with the text knocked out of it, so the menu
    /// bar shows through the number, like the macOS Spaces indicator.
    private static func drawBadge(_ text: NSAttributedString, in rect: NSRect, cornerRadius: CGFloat) {
        guard let context = NSGraphicsContext.current else { return }
        // The transparency layer keeps the knockout from punching through
        // anything already drawn beneath the badge.
        context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
        NSColor.labelColor.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()

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
