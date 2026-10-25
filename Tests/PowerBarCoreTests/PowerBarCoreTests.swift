import XCTest
@testable import PowerBarCore

final class SettingsTests: XCTestCase {
    func testParseOverridesKnownKeysOnly() {
        let s = Settings.parse("""
        # comment
        TAU = 4      # calmer
        JUMP_N=5
        WIDTH = 2
        UNKNOWN = 1
        STEP_ABS = abc
        """)
        XCTAssertEqual(s.tau, 4)
        XCTAssertEqual(s.jumpN, 5)
        XCTAssertEqual(s.width, 2)
        XCTAssertEqual(s.stepAbs, Settings().stepAbs)
    }

    /// Values that would stall the timer, divide by zero or crash on Int(_:)
    /// are ignored, so the default stays.
    func testParseIgnoresValuesOutOfRange() {
        let s = Settings.parse("""
        INTERVAL_MS = 0
        JUMP_N = 0
        WIDTH = 1e30
        TAU = -1
        MAX_W = nan
        STEP_REL = inf
        STEP_ABS = 0x10
        """)
        XCTAssertEqual(s, Settings())
        XCTAssertEqual(Settings.parse("INTERVAL_MS = 250").intervalMs, 250)
    }

    func testMaxWRejectsGlitches() {
        let s = Settings()
        XCTAssertTrue(s.isPlausible(34.1))
        XCTAssertTrue(s.isPlausible(500))
        XCTAssertFalse(s.isPlausible(2803.1))
        XCTAssertFalse(s.isPlausible(0))
        XCTAssertFalse(Settings.parse("MAX_W = 200").isPlausible(250))
    }
}

final class SmootherTests: XCTestCase {
    func testSmallNoiseKeepsNumberStill() {
        var s = Smoother(settings: Settings())
        XCTAssertTrue(s.add(10))
        for x in [10.5, 9.6, 10.8, 9.9, 10.4, 9.7] {
            XCTAssertFalse(s.add(x))
        }
        XCTAssertEqual(s.shown, 10)
    }

    func testPersistentJumpShowsAfterJumpN() {
        var s = Smoother(settings: Settings())
        s.add(10)
        XCTAssertFalse(s.add(40))
        XCTAssertFalse(s.add(40))
        XCTAssertTrue(s.add(40))
        XCTAssertEqual(s.shown, 40)
    }

    /// A spike, an SMC glitch and a lasting jump: shows 10 → 13 → 30.
    /// The 2803 W glitch must leave no trace.
    func testGlitchAndJumpScenario() {
        let settings = Settings()
        var s = Smoother(settings: settings)
        var titles: [String] = []
        let input = [10.0, 40, 10, 2803, 10, 10, 12, 30, 30, 30, 30, 31, 29, 30]
        for x in input where settings.isPlausible(x) && s.add(x) {
            titles.append(formatTitle(s.shown, width: 3))
        }
        XCTAssertEqual(titles, ["\u{2007}10W", "\u{2007}13W", "\u{2007}30W"])
        XCTAssertEqual(s.peak, 40)
    }

    func testFormatTitlePadsWithFigureSpaces() {
        XCTAssertEqual(formatTitle(7.4, width: 3), "\u{2007}\u{2007}7W")
        XCTAssertEqual(formatTitle(123, width: 3), "123W")
        XCTAssertEqual(formatTitle(5000, width: 3), "999W")
        XCTAssertEqual(formatTitle(nil, width: 3), "\u{2007}\u{2007}?W")
        XCTAssertEqual(formatTitle(.nan, width: 3), "\u{2007}\u{2007}?W")
    }

    func testMenuText() {
        XCTAssertEqual(formatWatts(12.345), "12.3 W")
        XCTAssertEqual(formatWatts(nil), "–")
        XCTAssertEqual(formatInfoLine(settings: Settings()),
                       "Source: SMC PSTR (whole system) · smoothing 8s · threshold ±1.5W/15%")
    }
}

final class SMCTests: XCTestCase {
    func testFourCCRoundTrip() {
        XCTAssertEqual(SMC.fourCC("PSTR"), 0x5053_5452)
        XCTAssertEqual(SMC.string(fourCC: 0x666C_7420), "flt ")
    }

    func testRequestLayout() {
        let b = SMC.request(key: "PSTR", command: SMC.cmdReadBytes, dataSize: 4)
        XCTAssertEqual(b.count, 80)
        XCTAssertEqual(Array(b[0..<4]), [0x52, 0x54, 0x53, 0x50])  // key, little-endian UInt32
        XCTAssertEqual(Array(b[28..<32]), [4, 0, 0, 0])            // keyInfo.dataSize
        XCTAssertEqual(b[42], 5)                                    // data8 = command
    }

    /// A key-info reply and a read reply as AppleSMC returned them for PSTR on an M5 Pro.
    func testParsesReplies() {
        var info = [UInt8](repeating: 0, count: 80)
        info.replaceSubrange(28..<36, with: [4, 0, 0, 0, 0x20, 0x74, 0x6C, 0x66])
        XCTAssertEqual(SMC.keyInfo(info).size, 4)
        XCTAssertEqual(SMC.keyInfo(info).type, "flt ")
        XCTAssertEqual(SMC.result(info), 0)

        var read = [UInt8](repeating: 0, count: 80)
        read.replaceSubrange(48..<52, with: [0x9A, 0xD9, 0x0A, 0x41])  // 8.678125 as float32 LE
        let value = SMC.decode(type: "flt ", bytes: SMC.bytes(read, size: 4))
        XCTAssertEqual(value!, 8.678, accuracy: 0.001)
    }

    func testDecodeRejectsOtherTypesAndNaN() {
        XCTAssertNil(SMC.decode(type: "ui32", bytes: [1, 0, 0, 0]))
        XCTAssertNil(SMC.decode(type: "flt ", bytes: [1, 0]))
        XCTAssertNil(SMC.decode(type: "flt ", bytes: [0, 0, 0xC0, 0x7F]))  // NaN
    }
}
