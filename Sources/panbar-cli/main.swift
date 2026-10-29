import Foundation
import PanbarCore

// Prints the windows on the current Desktop in Paneru's strip order.
//   panbar-cli         active Desktop only
//   panbar-cli --all   every Desktop Paneru knows about

let showAll = CommandLine.arguments.contains("--all")

func printWorkspace(_ workspace: WorkspaceState) {
    let marker = workspace.active ? " (active)" : ""
    print("Space \(workspace.nativeWorkspaceID)\(marker)")
    if workspace.windows.isEmpty {
        print("  (no windows)")
    }
    for (index, window) in workspace.windows.enumerated() {
        // * focused, ~ floating, · scrolled off-screen
        let flags = (window.focused ? "*" : " ") + (window.floating ? "~" : " ") + (window.visible ? " " : "·")
        print("  \(index + 1). [\(flags)] \(window.bundleID)  \(window.appName) — \(window.title)")
    }
}

do {
    let state = try PaneruClient.locate().queryState()
    if showAll {
        state.virtualWorkspaces.forEach(printWorkspace)
    } else if let workspace = state.activeWorkspace {
        printWorkspace(workspace)
    } else {
        print("Paneru reports no active workspace.")
    }
} catch {
    FileHandle.standardError.write(Data("panbar-cli: \(error)\n".utf8))
    exit(1)
}
