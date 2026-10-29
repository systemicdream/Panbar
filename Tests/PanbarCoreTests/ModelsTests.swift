import Foundation
import Testing
@testable import PanbarCore

// Captured from `paneru query state --json` (Paneru 0.5.2), trimmed.
private let sample = """
{"active":{"display_id":1,"focused_app_name":"Cider","focused_bundle_id":"sh.cider.genten.mac","focused_window_id":488,"focused_window_title":"Cider","native_workspace_id":6,"virtual_workspace_number":1},"timestamp":1793313930,"version":1,"virtual_workspaces":[{"active":false,"native_workspace_id":4,"number":1,"windows":[]},{"active":true,"native_workspace_id":6,"number":1,"windows":[{"app_name":"Ghostty","bundle_id":"com.mitchellh.ghostty","display_id":1,"floating":false,"focused":false,"frame":{"height":944,"width":756,"x":-751,"y":37},"title":"~/Projects/Panbar","visible":false,"window_id":752},{"app_name":"Cider","bundle_id":"sh.cider.genten.mac","display_id":1,"floating":false,"focused":true,"frame":{"height":944,"width":1512,"x":0,"y":37},"title":"Cider","visible":true,"window_id":488}]}]}
"""

@Test func decodesQueryStateInStripOrder() throws {
    let state = try JSONDecoder().decode(QueryState.self, from: Data(sample.utf8))

    #expect(state.version == 1)
    #expect(state.active.focusedWindowID == 488)

    let workspace = try #require(state.activeWorkspace)
    #expect(workspace.nativeWorkspaceID == 6)
    #expect(workspace.windows.map(\.bundleID) == ["com.mitchellh.ghostty", "sh.cider.genten.mac"])

    let ghostty = workspace.windows[0]
    #expect(!ghostty.visible)
    #expect(ghostty.frame?.x == -751)
    #expect(ghostty.role == nil)
    #expect(workspace.windows[1].focused)
}

@Test func toleratesMissingOptionalFields() throws {
    let json = """
    {"window_id":1,"bundle_id":"a.b","app_name":"A","title":"t","focused":false,"floating":true}
    """
    let window = try JSONDecoder().decode(WindowState.self, from: Data(json.utf8))
    #expect(window.visible)
    #expect(window.frame == nil)
    #expect(window.displayID == nil)
}
