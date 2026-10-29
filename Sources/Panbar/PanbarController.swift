import AppKit
import PanbarCore
import ServiceManagement

/// Owns the status item and keeps it in sync with Paneru.
///
/// Every subscribe event is treated as "something changed" and answered with a
/// fresh `query state`. Paneru emits move events throughout strip animations,
/// so refreshes are coalesced: at most one query is in flight, and events that
/// arrive meanwhile trigger exactly one follow-up.
@MainActor
final class PanbarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let icons = IconProvider()
    private lazy var renderer = StripRenderer(icons: icons)

    private var client: PaneruClient?
    private var subscription: PaneruSubscription?
    private var state: QueryState?
    private var desktops: [UInt64: Desktop] = [:]
    private var lastError: String?

    /// The width budget the current image was drawn for.
    private var renderedBudget: CGFloat?
    private var layoutTimer: Timer?

    private var refreshInFlight = false
    private var refreshPending = false
    private var restartDelay: TimeInterval = 1
    private static let maxRestartDelay: TimeInterval = 30

    func start() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
        render()
        watchMenuBarLayout()
        connect()
    }

    /// Other apps' status items come and go without telling anyone, so the
    /// room before the notch is rechecked when our item moves, when screens
    /// change, and every few seconds as a fallback.
    private func watchMenuBarLayout() {
        let center = NotificationCenter.default
        let recheck: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.renderIfBudgetChanged() }
        }
        if let window = statusItem.button?.window {
            center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main, using: recheck)
        }
        center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: recheck
        )
        layoutTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.renderIfBudgetChanged() }
        }
    }

    private func renderIfBudgetChanged() {
        guard lastError == nil, let button = statusItem.button,
              maxImageWidth(of: button) != renderedBudget
        else { return }
        render()
    }

    // MARK: - Paneru

    private func connect() {
        do {
            let client = try client ?? PaneruClient.locate()
            self.client = client

            let subscription = PaneruSubscription(client: client)
            subscription.onLine = { [weak self] _ in
                self?.restartDelay = 1
                self?.scheduleRefresh()
            }
            subscription.onExit = { [weak self] status in
                self?.subscriptionEnded(status: status)
            }
            try subscription.start()
            self.subscription = subscription
            scheduleRefresh()
        } catch {
            show(error: error)
            reconnectLater()
        }
    }

    private func subscriptionEnded(status: Int32) {
        subscription = nil
        show(error: "Lost connection to Paneru (subscribe exited with status \(status)).")
        reconnectLater()
    }

    private func reconnectLater() {
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, Self.maxRestartDelay)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.connect()
        }
    }

    private func scheduleRefresh() {
        guard let client else { return }
        if refreshInFlight {
            refreshPending = true
            return
        }
        refreshInFlight = true
        Task { [weak self] in
            let result = await Task.detached {
                Result { (try client.queryState(), SpaceResolver.currentDesktops()) }
            }.value
            guard let self else { return }
            switch result {
            case .success(let (state, desktops)):
                self.state = state
                self.desktops = desktops
                self.lastError = nil
                self.render()
            case .failure(let error):
                self.show(error: error)
            }
            self.refreshInFlight = false
            if self.refreshPending {
                self.refreshPending = false
                self.scheduleRefresh()
            }
        }
    }

    // MARK: - Status item

    private var activeWindows: [WindowState] {
        state?.activeWorkspace?.windows ?? []
    }

    private func desktop(for workspace: WorkspaceState) -> Desktop? {
        desktops[workspace.nativeWorkspaceID]
    }

    private func render() {
        guard let button = statusItem.button else { return }
        if lastError != nil {
            button.image = NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Panbar error"
            )
            button.toolTip = lastError
            button.setAccessibilityLabel("Panbar: \(lastError ?? "error")")
            return
        }
        let label = state?.activeWorkspace.flatMap(desktop(for:))?.shortTitle
        let budget = maxImageWidth(of: button)
        renderedBudget = budget
        let image = renderer.image(for: activeWindows, label: label, maxWidth: budget)
        button.image = image
        button.toolTip = nil
        // The strip is an image, so describe it for VoiceOver.
        let desktopName = state?.activeWorkspace.flatMap(desktop(for:))?.title ?? "Panbar"
        let appNames = activeWindows.map { $0.focused ? "\($0.appName), focused" : $0.appName }
        button.setAccessibilityLabel(
            appNames.isEmpty ? "\(desktopName): no windows" : "\(desktopName): \(appNames.joined(separator: "; "))"
        )
        if let path = ProcessInfo.processInfo.environment["PANBAR_DEBUG_SNAPSHOT"] {
            writeSnapshot(of: image, appearance: button.effectiveAppearance, to: path)
        }
    }

    /// Debug aid: writes the strip to a PNG at 2x, since menu bar managers
    /// like Ice can hide the item itself.
    private func writeSnapshot(of image: NSImage, appearance: NSAppearance, to path: String) {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * 2), pixelsHigh: Int(image.size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        appearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: image.size).fill()
            image.draw(in: NSRect(origin: .zero, size: image.size))
        }
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// The menu bar room left for the strip image, after the button's own
    /// padding around it.
    private func maxImageWidth(of button: NSStatusBarButton) -> CGFloat? {
        guard let window = button.window,
              let available = MenuBarSpace.availableWidth(for: window)
        else { return nil }
        let padding = max(0, window.frame.width - (button.image?.size.width ?? 0))
        return available - padding
    }

    private func show(error: Error) {
        show(error: String(describing: error))
    }

    private func show(error message: String) {
        lastError = message
        render()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let lastError {
            menu.addItem(disabledItem(lastError))
        } else if let workspace = state?.activeWorkspace {
            menu.addItem(disabledItem(desktop(for: workspace)?.title ?? "Space \(workspace.nativeWorkspaceID)"))
            if workspace.windows.isEmpty {
                menu.addItem(disabledItem("No windows"))
            }
            for window in workspace.windows {
                menu.addItem(item(for: window))
            }
        } else {
            menu.addItem(disabledItem("Waiting for Paneru…"))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("Refresh", #selector(refreshClicked), key: "r"))
        menu.addItem(launchAtLoginItem())
        menu.addItem(actionItem("Quit Panbar", #selector(quitClicked), key: "q"))
    }

    private func item(for window: WindowState) -> NSMenuItem {
        let title = window.title.isEmpty || window.title == window.appName
            ? window.appName
            : "\(window.appName) — \(window.title)"
        let item = NSMenuItem(title: truncate(title, to: 70), action: nil, keyEquivalent: "")
        let icon = icons.icon(for: window.bundleID).copy() as! NSImage
        icon.size = NSSize(width: 16, height: 16)
        item.image = icon
        item.state = window.focused ? .on : .off
        if !window.visible {
            item.toolTip = "Off-screen"
        }
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: truncate(title, to: 70), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func truncate(_ string: String, to length: Int) -> String {
        string.count > length ? String(string.prefix(length - 1)) + "…" : string
    }

    /// Login items need a real app bundle, so this is disabled under `swift run`.
    private func launchAtLoginItem() -> NSMenuItem {
        let item = actionItem("Launch at Login", #selector(launchAtLoginClicked), key: "")
        let isBundled = Bundle.main.bundleURL.pathExtension == "app"
        item.isEnabled = isBundled
        item.state = isBundled && SMAppService.mainApp.status == .enabled ? .on : .off
        return item
    }

    @objc private func launchAtLoginClicked() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Launch at Login"
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func refreshClicked() {
        scheduleRefresh()
    }

    @objc private func quitClicked() {
        subscription?.stop()
        NSApp.terminate(nil)
    }
}
