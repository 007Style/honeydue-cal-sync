import Foundation
import EventKit

/// Orchestrates the full sync cycle: read → diff → write → save state.
/// Both source and target are macOS Calendar.app calendars via EventKit.
final class SyncEngine {

    private let diffEngine = DiffEngine()
    let eventKit = EventKitSync()
    private var reader: CalendarReader?

    // MARK: - State persistence

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func loadStateFile() -> StateFile {
        guard let data = try? Data(contentsOf: AppPaths.stateURL),
              let file = try? decoder.decode(StateFile.self, from: data)
        else { return .empty }
        return file
    }

    private func saveStateFile(_ file: StateFile) throws {
        let data = try encoder.encode(file)
        try FileManager.default.createDirectory(at: AppPaths.appSupport,
                                                withIntermediateDirectories: true)
        try data.write(to: AppPaths.stateURL, options: .atomic)
    }

    // MARK: - Main sync

    func run(config: AppConfig) async throws -> SyncResult {
        Logger.shared.info("Sync started")

        // 1. Request EventKit access
        try await eventKit.requestAccess()

        // 1b. Warn if configured calendars no longer exist in the store
        ConfigManager.shared.validateCalendars(config: config, store: eventKit.store)

        // 2. Read source calendar
        let calReader = CalendarReader(store: eventKit.store)
        let current: [Meeting]
        do {
            current = try calReader.fetchMeetings(calendarID: config.sourceCalendarID,
                                                  lookaheadDays: config.lookaheadDays)
            Logger.shared.info("Source calendar: \(current.count) events in window")
        } catch {
            Logger.shared.error("Source calendar read failed: \(error)")
            throw error
        }

        // 3. Load the per-calendar state for the CURRENT target calendar.
        //    StateFile holds one SyncState keyed by targetCalendarID, so switching
        //    calendars and switching back always restores the correct ekEventIDs —
        //    no scanning required, no duplicates possible.
        var stateFile = loadStateFile()
        let snapshot  = stateFile.state(for: config.targetCalendarID)
        Logger.shared.info("Snapshot for target '\(config.targetCalendarName)': \(snapshot.meetings.count) meetings")

        // 4. Configure block title and verify target calendar exists
        eventKit.calendarBlockTitle = config.blockTitle
        guard eventKit.calendar(forID: config.targetCalendarID) != nil else {
            throw EventKitError.calendarNotFound(config.targetCalendarName)
        }

        // 5. Duplicate cleanup — remove any extra owned blocks on the target calendar
        //    that share the same start+end time. Uses osascript since EventKit reads
        //    are not available under ad-hoc signing.
        let dupsRemoved = eventKit.removeDuplicateOwnedEvents(calendarName: config.targetCalendarName)
        if dupsRemoved > 0 {
            Logger.shared.info("Removed \(dupsRemoved) duplicate owned block(s) from '\(config.targetCalendarName)'")
        }

        // 6. Block-title rename sweep — if blockTitle changed since the last sync
        //    to THIS target calendar, update all tracked events in state via their
        //    stored ekEventIDs (no calendar read needed).
        if let lastTitle = snapshot.lastBlockTitle, lastTitle != config.blockTitle {
            Logger.shared.info("Block title changed '\(lastTitle)' → '\(config.blockTitle)': updating \(snapshot.meetings.count) tracked events")
            for meeting in snapshot.meetings.values {
                guard let ekID = meeting.ekEventID else { continue }
                do {
                    try eventKit.updateEventTitleOnly(ekEventID: ekID,
                                                      newTitle: config.blockTitle,
                                                      sourceID: meeting.id)
                } catch {
                    Logger.shared.error("Title rename failed for \(ekID): \(error)")
                }
            }
            if !snapshot.meetings.isEmpty {
                try? eventKit.commit()
            }
        }

        // 7. Diff
        let diffResult = diffEngine.diff(current: current, snapshot: snapshot)
        Logger.shared.info("Diff: \(diffResult.toCreate.count) new, "
                         + "\(diffResult.toUpdate.count) changed, "
                         + "\(diffResult.toDelete.count) deleted")

        // 8. Apply changes
        var newSnapshot = snapshot
        var created = 0, updated = 0, deleted = 0
        var errors: [String] = []

        for var meeting in diffResult.toCreate {
            do {
                let ekID = try eventKit.createEvent(meeting: meeting,
                                                    calendarID: config.targetCalendarID)
                meeting.ekEventID = ekID
                newSnapshot.meetings[meeting.id] = meeting
                created += 1
                Logger.shared.info("Created: \(meeting.title)")
            } catch {
                errors.append("Create '\(meeting.title)': \(error.localizedDescription)")
                Logger.shared.error("Create failed: \(error)")
            }
        }

        for meeting in diffResult.toUpdate {
            guard let ekID = meeting.ekEventID else {
                errors.append("Update '\(meeting.title)': no EventKit ID")
                continue
            }
            do {
                try eventKit.updateEvent(ekEventID: ekID, meeting: meeting)
                newSnapshot.meetings[meeting.id] = meeting
                updated += 1
                Logger.shared.info("Updated: \(meeting.title)")
            } catch {
                errors.append("Update '\(meeting.title)': \(error.localizedDescription)")
                Logger.shared.error("Update failed: \(error)")
            }
        }

        for meeting in diffResult.toDelete {
            guard let ekID = meeting.ekEventID else {
                newSnapshot.meetings.removeValue(forKey: meeting.id)
                deleted += 1
                continue
            }
            do {
                try eventKit.deleteEvent(ekEventID: ekID)
                newSnapshot.meetings.removeValue(forKey: meeting.id)
                deleted += 1
                Logger.shared.info("Deleted: \(meeting.title)")
            } catch {
                errors.append("Delete '\(meeting.title)': \(error.localizedDescription)")
                Logger.shared.error("Delete failed: \(error)")
            }
        }

        // 9. Commit or rollback
        if errors.isEmpty {
            try eventKit.commit()
            newSnapshot.lastSyncISO = ISO8601DateFormatter().string(from: Date())
            newSnapshot.lastBlockTitle = config.blockTitle
            stateFile.setState(newSnapshot, for: config.targetCalendarID)
            try saveStateFile(stateFile)
            Logger.shared.info("Sync complete: \(created) created, \(updated) updated, \(deleted) deleted")
            return SyncResult(created: created, updated: updated, deleted: deleted, error: nil)
        } else {
            eventKit.rollback()
            let summary = errors.joined(separator: "; ")
            Logger.shared.error("Sync incomplete — rolled back. Errors: \(summary)")
            return SyncResult(created: created, updated: updated, deleted: deleted,
                              error: "Sync incomplete — \(summary). Will retry.")
        }
    }

}
