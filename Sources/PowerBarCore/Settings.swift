import Foundation

/// User settings, read from `~/.config/powerbar/config` (one `KEY = value` per line).
public struct Settings: Equatable {
    public var intervalMs = 1000   // sampling interval
    public var tau = 8.0           // smoothing in seconds (higher = calmer)
    public var stepAbs = 1.5       // minimum change in W before the number changes
    public var stepRel = 0.15      // ...or as a fraction of the displayed value (the larger wins)
    public var jumpAbs = 5.0       // a "substantial" jump in W
    public var jumpRel = 0.5       // ...and as a fraction of the displayed value
    public var jumpN = 3           // number of consecutive samples the jump must persist
    public var width = 3           // digit slots in the menu bar; 3 = up to 999 W
    public var maxW = 500.0        // readings above this are SMC glitches and are ignored

    public init() {}

    /// PSTR now and then gives a bogus value (thousands of W); such a reading
    /// must not reach the smoothing, the peak or the jump detection.
    public func isPlausible(_ watts: Double) -> Bool { watts > 0 && watts <= maxW }

    public static let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/powerbar/config")

    /// A config key: the accepted range and where the value goes.
    public struct Key {
        public let range: ClosedRange<Double>
        let apply: (inout Settings, Double) -> Void
    }

    /// Every key the config file understands. A value outside its range is
    /// ignored (the default stays), so a typo can't stall the timer, divide by
    /// zero or overflow `Int(_:)`. The README's settings table mirrors this.
    public static let keys: [String: Key] = [
        "INTERVAL_MS": Key(range: 100...60_000) { $0.intervalMs = Int($1) },
        "TAU": Key(range: 0.1...3600) { $0.tau = $1 },
        "STEP_ABS": Key(range: 0...1000) { $0.stepAbs = $1 },
        "STEP_REL": Key(range: 0...10) { $0.stepRel = $1 },
        "JUMP_ABS": Key(range: 0...1000) { $0.jumpAbs = $1 },
        "JUMP_REL": Key(range: 0...10) { $0.jumpRel = $1 },
        "JUMP_N": Key(range: 1...600) { $0.jumpN = Int($1) },
        "WIDTH": Key(range: 1...6) { $0.width = Int($1) },
        "MAX_W": Key(range: 1...100_000) { $0.maxW = $1 },
    ]

    public static func load(from url: URL = path) -> Settings {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return Settings() }
        return parse(text)
    }

    /// Unknown keys, values that aren't plain decimal numbers and values out of
    /// range are ignored.
    public static func parse(_ text: String) -> Settings {
        var s = Settings()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let key = keys[parts[0].trimmingCharacters(in: .whitespaces)] else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard value.allSatisfy({ "0123456789.+-eE".contains($0) }),  // decimal only, no hex
                  let v = Double(value), key.range.contains(v) else { continue }
            key.apply(&s, v)
        }
        return s
    }
}
