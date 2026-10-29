import Foundation

/// Runs `paneru subscribe --json` and reports each event line on the main
/// actor. Paneru sends a snapshot as soon as the subscription opens, then one
/// line per change. The process exits when the daemon goes away; the owner
/// decides whether to start a new subscription.
@MainActor
public final class PaneruSubscription {
    private let process = Process()
    private var buffer = LineBuffer()

    public var onLine: ((String) -> Void)?
    public var onExit: ((Int32) -> Void)?

    public init(client: PaneruClient) {
        process.executableURL = client.binaryURL
        process.arguments = ["subscribe", "--json"]
        process.standardError = FileHandle.nullDevice
    }

    public func start() throws {
        let stdout = Pipe()
        process.standardOutput = stdout

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.receive(data) }
            }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.onExit?(status) }
            }
        }
        try process.run()
    }

    public func stop() {
        if process.isRunning {
            process.terminate()
        }
    }

    private func receive(_ data: Data) {
        for line in buffer.append(data) {
            onLine?(line)
        }
    }
}
