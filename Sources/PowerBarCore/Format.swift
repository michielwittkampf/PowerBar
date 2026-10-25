import Foundation

/// Empty digit slots are padded with a FIGURE SPACE (U+2007), which is as wide
/// as a digit. Together with tabular digits this keeps the title the same width.
public func formatTitle(_ watts: Double?, width: Int) -> String {
    let number: String
    if let w = watts, w.isFinite {
        number = String(Int(min(max(w, 0), pow(10, Double(width)) - 1).rounded()))
    } else {
        number = "?"
    }
    return String(repeating: "\u{2007}", count: max(0, width - number.count)) + number + "W"
}

/// "12.3 W", or "–" when there is no value yet. Used in the dropdown.
public func formatWatts(_ watts: Double?) -> String {
    watts.map { String(format: "%.1f W", $0) } ?? "–"
}

/// The small info row in the dropdown: the source and the main settings.
public func formatSourceLine(source: String, settings s: Settings) -> String {
    func g(_ x: Double) -> String { String(format: "%g", x) }
    let percent = Int((s.stepRel * 100).rounded())
    return "Source: \(source) · smoothing \(g(s.tau))s · threshold ±\(g(s.stepAbs))W/\(percent)%"
}

/// Where the documentation and the issue tracker live.
public enum Project {
    public static let docs = URL(string: "https://github.com/michielwittkampf/powerbar#readme")!
}
