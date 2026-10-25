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

    func testMaxWRejectsGlitches() {
        let s = Settings()
        XCTAssertTrue(s.isPlausible(34.1))
        XCTAssertTrue(s.isPlausible(500))
        XCTAssertFalse(s.isPlausible(2803.1))
        XCTAssertFalse(s.isPlausible(0))
        XCTAssertFalse(Settings.parse("MAX_W = 200").isPlausible(250))
    }
}

final class SampleTests: XCTestCase {
    func testPrefersSysPowerAndFallsBackToAllPower() {
        let sys = Sample(json: Data(#"{"sys_power": 14.9, "all_power": 0.7, "cpu_power": 0.2}"#.utf8))
        XCTAssertEqual(sys?.power, 14.9)
        XCTAssertEqual(sys?.cpu, 0.2)
        let chip = Sample(json: Data(#"{"sys_power": 0, "all_power": 3.5}"#.utf8))
        XCTAssertEqual(chip?.power, 3.5)
        XCTAssertEqual(chip?.source, "chip only (CPU+GPU+ANE)")
    }

    func testOldNestedFormatAndJunk() {
        XCTAssertEqual(Sample(json: Data(#"{"metrics": {"sys_power": 9}}"#.utf8))?.power, 9)
        XCTAssertNil(Sample(json: Data("not json".utf8)))
        XCTAssertNil(Sample(json: Data(#"{"sys_power": 0}"#.utf8)))
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

    /// Same input as a fake macmon fed to powerbar.py, which shows 10 → 13 → 30.
    /// The 2803 W glitch must leave no trace.
    func testMatchesPythonPlugin() {
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
    }
}
