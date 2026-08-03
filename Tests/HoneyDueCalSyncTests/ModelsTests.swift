import XCTest
@testable import HoneyDueCalSync

final class ModelsTests: XCTestCase {

    // MARK: - Meeting encode/decode

    func testMeeting_roundTrips() throws {
        let original = Meeting(id: "abc-123",
                               title: "Standup",
                               startISO: "2025-06-01T09:00:00+00:00",
                               endISO:   "2025-06-01T09:30:00+00:00",
                               hash: "deadbeef",
                               ekEventID: "EK-42")
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Meeting.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMeeting_nilEKEventID_roundTrips() throws {
        let original = Meeting(id: "xyz", title: "Review",
                               startISO: "2025-06-02T14:00:00+00:00",
                               endISO:   "2025-06-02T15:00:00+00:00",
                               hash: "cafebabe",
                               ekEventID: nil)
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Meeting.self, from: data)
        XCTAssertNil(decoded.ekEventID)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - SyncState

    func testSyncState_empty_hasMeetings() {
        let s = SyncState.empty
        XCTAssertTrue(s.meetings.isEmpty)
        XCTAssertNil(s.lastSyncISO)
        XCTAssertNil(s.lastBlockTitle)
    }

    func testSyncState_roundTrips() throws {
        let meeting = Meeting(id: "m1", title: "Demo",
                              startISO: "2025-06-03T10:00:00+00:00",
                              endISO:   "2025-06-03T11:00:00+00:00",
                              hash: "aabbcc", ekEventID: "EK-1")
        var state = SyncState.empty
        state.meetings["m1"] = meeting
        state.lastSyncISO    = "2025-06-03T11:00:00Z"
        state.lastBlockTitle = "IBM - BLOCK"

        let data    = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SyncState.self, from: data)
        XCTAssertEqual(decoded.meetings["m1"], meeting)
        XCTAssertEqual(decoded.lastSyncISO, "2025-06-03T11:00:00Z")
        XCTAssertEqual(decoded.lastBlockTitle, "IBM - BLOCK")
    }

    // MARK: - StateFile

    func testStateFile_stateForUnknownCalendar_returnsEmpty() {
        let sf = StateFile.empty
        let s  = sf.state(for: "unknown-id")
        XCTAssertTrue(s.meetings.isEmpty)
    }

    func testStateFile_setAndGet_roundTrips() {
        var sf = StateFile.empty
        var state = SyncState.empty
        state.lastBlockTitle = "BUSY"
        sf.setState(state, for: "cal-1")
        XCTAssertEqual(sf.state(for: "cal-1").lastBlockTitle, "BUSY")
        XCTAssertTrue(sf.state(for: "cal-2").meetings.isEmpty)
    }

    // MARK: - AppConfig defaults

    func testAppConfig_defaultValues() {
        let c = AppConfig.default
        XCTAssertEqual(c.lookaheadDays, 30)
        XCTAssertEqual(c.syncIntervalMinutes, 60)
        XCTAssertEqual(c.blockTitle, "IBM - BLOCK")
        XCTAssertTrue(c.launchAtLogin)
        XCTAssertFalse(c.startMinimized)
    }

    func testAppConfig_roundTrips() throws {
        var c = AppConfig()
        c.sourceCalendarID   = "src"
        c.targetCalendarID   = "tgt"
        c.lookaheadDays      = 45
        c.syncIntervalMinutes = 240
        c.blockTitle         = "WORK"

        let data    = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.sourceCalendarID,    "src")
        XCTAssertEqual(decoded.targetCalendarID,    "tgt")
        XCTAssertEqual(decoded.lookaheadDays,       45)
        XCTAssertEqual(decoded.syncIntervalMinutes, 240)
        XCTAssertEqual(decoded.blockTitle,          "WORK")
    }

    // MARK: - SyncResult

    func testSyncResult_isSuccess_whenNoError() {
        let r = SyncResult(created: 1, updated: 0, deleted: 0, error: nil)
        XCTAssertTrue(r.isSuccess)
    }

    func testSyncResult_isFailure_whenErrorPresent() {
        let r = SyncResult(created: 0, updated: 0, deleted: 0, error: "Something went wrong")
        XCTAssertFalse(r.isSuccess)
    }

    func testSyncResult_summary_nothingToDo() {
        let r = SyncResult(created: 0, updated: 0, deleted: 0, error: nil)
        XCTAssertEqual(r.summary, "Sync completed — nothing to do")
    }

    func testSyncResult_summary_withChanges() {
        let r = SyncResult(created: 2, updated: 1, deleted: 3, error: nil)
        XCTAssertEqual(r.summary, "Sync completed — 2 new, 1 updated, 3 deleted")
    }

    func testSyncResult_summary_errorTakesPrecedence() {
        let r = SyncResult(created: 5, updated: 0, deleted: 0, error: "EventKit denied")
        XCTAssertEqual(r.summary, "EventKit denied")
    }

    // MARK: - AppPaths

    func testAppPaths_resolvedLogURL_emptyPath_returnsDefault() {
        var c = AppConfig()
        c.logPath = ""
        XCTAssertEqual(AppPaths.resolvedLogURL(config: c), AppPaths.logURL)
    }

    func testAppPaths_resolvedLogURL_relativePath_returnsDefault() {
        var c = AppConfig()
        c.logPath = "relative/path/run.log"
        XCTAssertEqual(AppPaths.resolvedLogURL(config: c), AppPaths.logURL)
    }

    func testAppPaths_resolvedLogURL_absolutePath_returnsThatPath() {
        var c = AppConfig()
        c.logPath = "/tmp/myapp.log"
        XCTAssertEqual(AppPaths.resolvedLogURL(config: c),
                       URL(fileURLWithPath: "/tmp/myapp.log"))
    }
}
