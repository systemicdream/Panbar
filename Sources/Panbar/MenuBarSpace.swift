import AppKit

/// Measures how wide the status item can get before it would push other menu
/// bar items under the notch.
@MainActor
enum MenuBarSpace {
    /// Gap kept between the leftmost status item and the notch.
    static let notchMargin: CGFloat = 8

    /// The widest the status item can be, or nil when its screen has no notch
    /// (or it isn't on screen, e.g. tucked into Ice's hidden section).
    ///
    /// Growing the item shifts every item to its left further left, so the
    /// budget is its current width plus the free space between the notch and
    /// the leftmost visible item.
    static func availableWidth(for statusWindow: NSWindow?) -> CGFloat? {
        guard let statusWindow,
              let screen = statusWindow.screen,
              let rightOfNotch = screen.auxiliaryTopRightArea
        else { return nil }

        let notchRight = rightOfNotch.minX
        let ownFrame = statusWindow.frame
        let ownWidth = ownFrame.minX >= notchRight ? ownFrame.width : 0

        let items = statusItemFrames(on: screen)
        // Ignore anything reaching past the screen's left edge: menu bar
        // managers park hidden items, or a huge spacer, off there.
        let leftmost = items
            .filter { $0.maxX > notchRight && $0.minX >= screen.frame.minX }
            .map(\.minX)
            .min() ?? screen.frame.maxX

        return max(0, ownWidth + leftmost - notchRight - notchMargin)
    }

    /// Frames of the status item windows in the menu bar on `screen`. Reading
    /// window bounds doesn't need Screen Recording permission.
    private static func statusItemFrames(on screen: NSScreen) -> [CGRect] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.maxY
        else { return [] }
        // Window bounds use a top-left origin on the primary display.
        let menuBarTop = primaryHeight - screen.frame.maxY

        return info.compactMap { window -> CGRect? in
            guard (window[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.statusWindow)),
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  abs(rect.minY - menuBarTop) < 1,
                  rect.maxX > screen.frame.minX, rect.minX < screen.frame.maxX
            else { return nil }
            return rect
        }
    }
}
