import CoreGraphics
import Foundation

// Private SkyLight API (re-exported by CoreGraphics); yabai and other window
// managers rely on it. It lists each display's Spaces in Mission Control order.
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

/// How Mission Control names a Space.
public enum Desktop: Equatable, Sendable {
    /// "Desktop N", numbered per display.
    case desktop(Int)
    /// A full-screen app's Space, which Mission Control doesn't number.
    case fullScreen

    public var title: String {
        switch self {
        case .desktop(let number): "Desktop \(number)"
        case .fullScreen: "Full Screen"
        }
    }

    public var shortTitle: String {
        switch self {
        case .desktop(let number): "\(number)"
        case .fullScreen: "FS"
        }
    }
}

/// Maps Paneru's `native_workspace_id` (the macOS Space ID) to the Desktop
/// number shown in Mission Control.
public enum SpaceResolver {
    /// Reads the current Space layout. Cheap enough to call on every refresh,
    /// which keeps numbering right after Desktops are added or reordered.
    public static func currentDesktops() -> [UInt64: Desktop] {
        guard let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] else {
            return [:]
        }
        return desktops(fromManagedDisplaySpaces: displays)
    }

    static func desktops(fromManagedDisplaySpaces displays: [[String: Any]]) -> [UInt64: Desktop] {
        var result: [UInt64: Desktop] = [:]
        for display in displays {
            var number = 0
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                guard let id = (space["ManagedSpaceID"] as? NSNumber)?.uint64Value else { continue }
                // type 0 is a user Desktop; 4 is a full-screen app.
                if (space["type"] as? NSNumber)?.intValue == 0 {
                    number += 1
                    result[id] = .desktop(number)
                } else {
                    result[id] = .fullScreen
                }
            }
        }
        return result
    }
}
