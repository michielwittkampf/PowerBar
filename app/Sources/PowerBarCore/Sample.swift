import Foundation

/// One line of `macmon pipe` output, reduced to what we show.
public struct Sample: Equatable {
    public var power: Double       // the value we display
    public var source: String      // where `power` came from
    public var cpu = 0.0, gpu = 0.0, ane = 0.0, ram = 0.0

    /// Returns nil for unparsable lines and readings without power.
    public init?(json line: Data) {
        guard var d = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { return nil }
        // macmon >= 0.8 puts the fields flat in the JSON object; older ones under "metrics"
        if d["sys_power"] == nil, let m = d["metrics"] as? [String: Any] { d = m }
        func num(_ k: String) -> Double { (d[k] as? NSNumber)?.doubleValue ?? 0 }

        let sys = num("sys_power")
        if sys > 0 {
            power = sys
            source = "PSTR (whole system)"
        } else {
            power = num("all_power")
            source = "chip only (CPU+GPU+ANE)"
        }
        guard power > 0 else { return nil }
        cpu = num("cpu_power"); gpu = num("gpu_power"); ane = num("ane_power"); ram = num("ram_power")
    }
}
