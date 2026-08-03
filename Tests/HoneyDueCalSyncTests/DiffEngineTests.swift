import XCTest
@testable import HoneyDueCalSync

final class DiffEngineTests: XCTestCase {

    let engine = DiffEngine()

    // MARK: - Helpers

    private func meeting(id: String, title: String = "Meeting",
                         start: String = "2025-01-01T09:00:00+00:00",
                         end:   String = "2025-01-01T10:00:00+00:00",
                         ekID:  String? = nil) -> Meeting {
        let hash = "\(id)\(start)\(end)".data(using: .utf8)!
                        .map { String(format: "%02x", $0) }.joined()
        return Meeting(id: id, title: title, startISO: start, endISO: end,
                       hash: hash, ekEventID: ekID)
    }

    private func state(_ meetings: [Meeting]) -> SyncState {
        let dict = Dictionary(uniqueKeysWithValues: meetings.map { ($0.id, $0) })
        return SyncState(meetings: dict, lastSyncISO: nil, lastBlockTitle: nil)
    }

    // MARK: - New event

    func testNewEvent_isCreated() {
        let current  = [meeting(id: "A")]
        let snapshot = SyncState.empty
        let result   = engine.diff(current: current, snapshot: snapshot)
        XCTAssertEqual(result.toCreate.count, 1)
        XCTAssertEqual(result.toCreate[0].id, "A")
        XCTAssertTrue(result.toUpdate.isEmpty)
        XCTAssertTrue(result.toDelete.isEmpty)
    }

    // MARK: - Unchanged event

    func testUnchangedEvent_isSkipped() {
        let m        = meeting(id: "A")
        let result   = engine.diff(current: [m], snapshot: state([m]))
        XCTAssertTrue(result.toCreate.isEmpty)
        XCTAssertTrue(result.toUpdate.isEmpty)
        XCTAssertTrue(result.toDelete.isEmpty)
    }

    // MARK: - Changed event (time shifted)

    func testChangedEvent_isUpdated() {
        let original = meeting(id: "A", start: "2025-01-01T09:00:00+00:00",
                                        end:   "2025-01-01T10:00:00+00:00",
                                        ekID:  "EK-123")
        let updated  = meeting(id: "A", start: "2025-01-01T10:00:00+00:00",
                                        end:   "2025-01-01T11:00:00+00:00")
        let result   = engine.diff(current: [updated], snapshot: state([original]))
        XCTAssertTrue(result.toCreate.isEmpty)
        XCTAssertEqual(result.toUpdate.count, 1)
        XCTAssertEqual(result.toUpdate[0].id, "A")
        XCTAssertTrue(result.toDelete.isEmpty)
    }

    func testChangedEvent_preservesEKEventID() {
        let original = meeting(id: "A", start: "2025-01-01T09:00:00+00:00",
                                        end:   "2025-01-01T10:00:00+00:00",
                                        ekID:  "EK-999")
        let shifted  = meeting(id: "A", start: "2025-01-01T11:00:00+00:00",
                                        end:   "2025-01-01T12:00:00+00:00")
        let result   = engine.diff(current: [shifted], snapshot: state([original]))
        XCTAssertEqual(result.toUpdate[0].ekEventID, "EK-999",
                       "ekEventID must be carried forward from snapshot so we can update the existing EK event")
    }

    // MARK: - Deleted event

    func testDeletedEvent_isRemoved() {
        let m      = meeting(id: "A", ekID: "EK-456")
        let result = engine.diff(current: [], snapshot: state([m]))
        XCTAssertTrue(result.toCreate.isEmpty)
        XCTAssertTrue(result.toUpdate.isEmpty)
        XCTAssertEqual(result.toDelete.count, 1)
        XCTAssertEqual(result.toDelete[0].id, "A")
    }

    // MARK: - Mixed batch

    func testMixedBatch() {
        let keep    = meeting(id: "keep")
        let changed = meeting(id: "changed", start: "2025-02-01T09:00:00+00:00",
                                             end:   "2025-02-01T10:00:00+00:00", ekID: "EK-C")
        let gone    = meeting(id: "gone",    ekID: "EK-G")
        let newOne  = meeting(id: "new")

        let changedShifted = meeting(id: "changed",
                                     start: "2025-02-01T11:00:00+00:00",
                                     end:   "2025-02-01T12:00:00+00:00")

        let snapshot = state([keep, changed, gone])
        let current  = [keep, changedShifted, newOne]
        let result   = engine.diff(current: current, snapshot: snapshot)

        XCTAssertEqual(result.toCreate.map(\.id), ["new"])
        XCTAssertEqual(result.toUpdate.map(\.id), ["changed"])
        XCTAssertEqual(result.toDelete.map(\.id), ["gone"])
    }

    // MARK: - Empty inputs

    func testBothEmpty_producesNoOps() {
        let result = engine.diff(current: [], snapshot: .empty)
        XCTAssertTrue(result.toCreate.isEmpty)
        XCTAssertTrue(result.toUpdate.isEmpty)
        XCTAssertTrue(result.toDelete.isEmpty)
    }
}
