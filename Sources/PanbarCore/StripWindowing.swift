/// Chooses which slice of a strip to show when it doesn't all fit.
public enum StripWindowing {
    /// The window to center on: the focused one, else the first one on
    /// screen, else the start of the strip.
    public static func anchor(in windows: [WindowState]) -> Int {
        windows.firstIndex(where: \.focused) ?? windows.firstIndex(where: \.visible) ?? 0
    }

    /// A run of `capacity` indices around `anchor`, shifted to stay inside
    /// `0..<count` so the slice never comes up short at either end.
    public static func range(count: Int, anchor: Int, capacity: Int) -> Range<Int> {
        guard capacity < count else { return 0..<count }
        let capacity = max(capacity, 0)
        let start = min(max(anchor - (capacity - 1) / 2, 0), count - capacity)
        return start..<(start + capacity)
    }
}
