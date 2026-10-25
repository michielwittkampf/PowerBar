import Foundation

/// User settings. Same keys, defaults and limits as the SwiftBar plugin, read from
/// the same file (`~/.config/powerbar/config`, one `KEY=value` per line).
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

    /// The accepted range per key. A value outside it is ignored (the default
    /// stays), so a typo can't stall the timer, divide by zero or overflow.
    /// Keep in sync with `LIMITS` in powerbar.py.
    public static let limits: [String: ClosedRange<Double>] = [
        "INTERVAL_MS": 100...60_000,
        "TAU": 0.1...3600,
        "STEP_ABS": 0...1000,
        "STEP_REL": 0...10,
        "JUMP_ABS": 0...1000,
        "JUMP_REL": 0...10,
        "JUMP_N": 1...600,
        "WIDTH": 1...6,
        "MAX_W": 1...100_000,
    ]

    public static func load(from url: URL = path) -> Settings {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return Settings() }
        return parse(text)
    }

    /// Unknown keys, unparsable values and values out of range are ignored, like in the plugin.
    public static func parse(_ text: String) -> Settings {
        var s = Settings()
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard value.allSatisfy({ "0123456789.+-eE".contains($0) }),  // decimal only, no hex
                  let v = Double(value),
                  let range = limits[key], range.contains(v) else { continue }
            switch key {
            case "INTERVAL_MS": s.intervalMs = Int(v)
            case "TAU": s.tau = v
            case "STEP_ABS": s.stepAbs = v
            case "STEP_REL": s.stepRel = v
            case "JUMP_ABS": s.jumpAbs = v
            case "JUMP_REL": s.jumpRel = v
            case "JUMP_N": s.jumpN = Int(v)
            case "WIDTH": s.width = Int(v)
            case "MAX_W": s.maxW = v
            default: break
            }
        }
        return s
    }
}
