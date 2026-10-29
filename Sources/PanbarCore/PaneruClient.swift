import Foundation

public enum PaneruError: Error, CustomStringConvertible {
    case binaryNotFound(searched: [String])
    case commandFailed(status: Int32, stderr: String)
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case .binaryNotFound(let searched):
            "paneru binary not found (searched: \(searched.joined(separator: ", "))). Set PANBAR_PANERU_PATH to override."
        case .commandFailed(let status, let stderr):
            "paneru exited with status \(status): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .unsupportedVersion(let version):
            "unsupported paneru state version \(version) (expected \(PaneruClient.supportedStateVersion))"
        }
    }
}

/// Talks to a running Paneru daemon through its CLI.
public struct PaneruClient: Sendable {
    public static let supportedStateVersion = 1

    public let binaryURL: URL

    public init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }

    /// Finds the `paneru` binary. GUI apps don't inherit the shell's PATH, so
    /// common install locations are checked before falling back to PATH.
    public static func locate(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> PaneruClient {
        var candidates: [String] = []
        if let override = environment["PANBAR_PANERU_PATH"], !override.isEmpty {
            candidates.append(override)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates += ["/opt/homebrew/bin/paneru", "/usr/local/bin/paneru", "\(home)/.cargo/bin/paneru"]
        candidates += (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { "\($0)/paneru" }

        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PaneruError.binaryNotFound(searched: candidates)
        }
        return PaneruClient(binaryURL: URL(fileURLWithPath: path))
    }

    public func queryState() throws -> QueryState {
        let data = try run(["query", "state", "--json"])
        let state = try JSONDecoder().decode(QueryState.self, from: data)
        guard state.version == Self.supportedStateVersion else {
            throw PaneruError.unsupportedVersion(state.version)
        }
        return state
    }

    private func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw PaneruError.commandFailed(
                status: process.terminationStatus,
                stderr: String(decoding: errorOutput, as: UTF8.self)
            )
        }
        return output
    }
}
