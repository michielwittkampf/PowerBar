import Foundation

/// The calm-but-alert number:
/// - the reading is smoothed with an EMA (time constant `tau`);
/// - the shown number only changes at `max(stepAbs, stepRel * shown)`;
/// - a large jump that persists `jumpN` samples is shown immediately;
/// - during a possible jump the normal updates are suppressed.
public struct Smoother {
    public let settings: Settings
    public private(set) var ema: Double?
    public private(set) var shown: Double?
    public private(set) var peak = 0.0
    private var jump: [Double] = []
    private let alpha: Double

    public init(settings: Settings) {
        self.settings = settings
        let dt = Double(settings.intervalMs) / 1000
        alpha = 1 - exp(-dt / settings.tau)
    }

    /// Feeds one reading; returns true when the shown number changed.
    @discardableResult
    public mutating func add(_ raw: Double) -> Bool {
        let s = settings
        peak = max(peak, raw)
        let e = ema.map { $0 + alpha * (raw - $0) } ?? raw
        ema = e

        guard let current = shown else {
            shown = e
            return true
        }
        // fast path: show a large, persistent jump immediately
        if abs(raw - current) >= max(s.jumpAbs, s.jumpRel * current) {
            jump.append(raw)
        } else {
            jump.removeAll()
        }
        if jump.count >= s.jumpN {
            let avg = jump.suffix(s.jumpN).reduce(0, +) / Double(s.jumpN)
            ema = avg
            jump.removeAll()
            shown = avg
            return true
        }
        // normal path: the smoothed value differs enough
        // (not during a possible jump; we wait that out)
        if jump.isEmpty && abs(e - current) >= max(s.stepAbs, s.stepRel * current) {
            shown = e
            return true
        }
        return false
    }
}
