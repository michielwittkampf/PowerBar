import Foundation

/// One power reading, reduced to what we show.
public struct Sample: Equatable {
    public var power: Double       // the value we display
    public var source: String      // where `power` came from

    public init(power: Double, source: String) {
        self.power = power
        self.source = source
    }
}
