import XCTest
@testable import HoneyDueCalSync

final class AppConfigTests: XCTestCase {

    // MARK: - Helpers

    private func validConfig() -> AppConfig {
        var c = AppConfig()
        c.sourceCalendarID = "source-id"
        c.targetCalendarID = "target-id"
        c.lookaheadDays    = 30
        c.syncIntervalMinutes = 60
        c.blockTitle       = "IBM - BLOCK"
        return c
    }

    private func validate(_ config: AppConfig) throws {
        try ConfigManager.shared.validate(config)
    }

    // MARK: - Valid config passes

    func testValidConfig_passes() {
        XCTAssertNoThrow(try validate(validConfig()))
    }

    // MARK: - sourceCalendarID

    func testEmptySourceCalendarID_throws() {
        var c = validConfig()
        c.sourceCalendarID = ""
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "sourceCalendarID")
        }
    }

    // MARK: - targetCalendarID

    func testEmptyTargetCalendarID_throws() {
        var c = validConfig()
        c.targetCalendarID = ""
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "targetCalendarID")
        }
    }

    func testSameSourceAndTarget_throws() {
        var c = validConfig()
        c.targetCalendarID = c.sourceCalendarID
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "sourceCalendarID")
        }
    }

    // MARK: - lookaheadDays

    func testLookaheadDaysTooLow_throws() {
        var c = validConfig()
        c.lookaheadDays = 0
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "lookaheadDays")
        }
    }

    func testLookaheadDaysTooHigh_throws() {
        var c = validConfig()
        c.lookaheadDays = 101
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "lookaheadDays")
        }
    }

    func testLookaheadDaysBoundaries_pass() {
        var c = validConfig()
        c.lookaheadDays = 1
        XCTAssertNoThrow(try validate(c))
        c.lookaheadDays = 100
        XCTAssertNoThrow(try validate(c))
    }

    // MARK: - syncIntervalMinutes

    func testAllValidIntervals_pass() {
        let valid = [1, 15, 30, 60, 120, 240, 360, 720, 1440]
        for minutes in valid {
            var c = validConfig()
            c.syncIntervalMinutes = minutes
            XCTAssertNoThrow(try validate(c), "interval \(minutes) should be valid")
        }
    }

    func testInvalidInterval_throws() {
        var c = validConfig()
        c.syncIntervalMinutes = 45   // not in the valid set
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "syncIntervalMinutes")
        }
    }

    func testHourlyStepsNoLongerValid_throws() {
        // 180 was valid in the old 60-step scheme — must be rejected now
        var c = validConfig()
        c.syncIntervalMinutes = 180
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "syncIntervalMinutes")
        }
    }

    // MARK: - blockTitle

    func testEmptyBlockTitle_throws() {
        var c = validConfig()
        c.blockTitle = "   "
        XCTAssertThrowsError(try validate(c)) { error in
            let ve = error as? ConfigManager.ValidationError
            XCTAssertEqual(ve?.field, "blockTitle")
        }
    }

    func testBlockTitle_passes() {
        var c = validConfig()
        c.blockTitle = "BUSY"
        XCTAssertNoThrow(try validate(c))
    }
}
