import Foundation

/// Splits a byte stream into newline-terminated lines, holding any trailing
/// partial line until the rest of it arrives.
public struct LineBuffer: Sendable {
    private var pending = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [String] {
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: pending[pending.startIndex..<newline], as: UTF8.self)
            pending.removeSubrange(pending.startIndex...newline)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}
