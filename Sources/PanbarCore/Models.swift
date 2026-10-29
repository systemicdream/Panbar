import Foundation

/// The document returned by `paneru query state --json`.
///
/// Mirrors `QueryState` in Paneru's `src/types/state.rs`. Paneru builds each
/// workspace's `windows` by walking the strip's columns left to right, so the
/// array order is the on-strip order.
public struct QueryState: Codable, Sendable, Equatable {
    public var version: Int
    public var timestamp: UInt64
    public var active: ActiveState
    public var virtualWorkspaces: [WorkspaceState]

    enum CodingKeys: String, CodingKey {
        case version, timestamp, active
        case virtualWorkspaces = "virtual_workspaces"
    }

    /// The workspace that is currently showing, if Paneru reports one.
    public var activeWorkspace: WorkspaceState? {
        virtualWorkspaces.first(where: \.active)
            ?? virtualWorkspaces.first { $0.nativeWorkspaceID == active.nativeWorkspaceID }
    }
}

public struct ActiveState: Codable, Sendable, Equatable {
    public var displayID: UInt32?
    public var nativeWorkspaceID: UInt64?
    public var virtualWorkspaceNumber: UInt32?
    public var focusedWindowID: Int32?
    public var focusedBundleID: String?
    public var focusedAppName: String?
    public var focusedWindowTitle: String?

    enum CodingKeys: String, CodingKey {
        case displayID = "display_id"
        case nativeWorkspaceID = "native_workspace_id"
        case virtualWorkspaceNumber = "virtual_workspace_number"
        case focusedWindowID = "focused_window_id"
        case focusedBundleID = "focused_bundle_id"
        case focusedAppName = "focused_app_name"
        case focusedWindowTitle = "focused_window_title"
    }
}

/// One Paneru strip. Paneru calls these "virtual workspaces"; with a single
/// row per Space there is exactly one per macOS Desktop.
public struct WorkspaceState: Codable, Sendable, Equatable {
    public var number: UInt32
    public var nativeWorkspaceID: UInt64
    public var active: Bool
    public var windows: [WindowState]

    enum CodingKeys: String, CodingKey {
        case number, active, windows
        case nativeWorkspaceID = "native_workspace_id"
    }
}

public struct WindowState: Codable, Sendable, Equatable, Identifiable {
    public var windowID: Int32
    public var bundleID: String
    public var appName: String
    public var title: String
    public var role: String?
    public var subrole: String?
    public var focused: Bool
    public var floating: Bool
    public var displayID: UInt32?
    public var frame: Frame?
    /// Not minimized or hidden, and showing more than Paneru's edge sliver.
    public var visible: Bool

    public var id: Int32 { windowID }

    enum CodingKeys: String, CodingKey {
        case windowID = "window_id"
        case bundleID = "bundle_id"
        case appName = "app_name"
        case displayID = "display_id"
        case title, role, subrole, focused, floating, frame, visible
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windowID = try c.decode(Int32.self, forKey: .windowID)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        appName = try c.decode(String.self, forKey: .appName)
        title = try c.decode(String.self, forKey: .title)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        subrole = try c.decodeIfPresent(String.self, forKey: .subrole)
        focused = try c.decode(Bool.self, forKey: .focused)
        floating = try c.decode(Bool.self, forKey: .floating)
        displayID = try c.decodeIfPresent(UInt32.self, forKey: .displayID)
        frame = try c.decodeIfPresent(Frame.self, forKey: .frame)
        // Older Paneru builds don't report visibility; assume visible.
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true
    }
}

public struct Frame: Codable, Sendable, Equatable {
    public var x: Int32
    public var y: Int32
    public var width: Int32
    public var height: Int32
}
