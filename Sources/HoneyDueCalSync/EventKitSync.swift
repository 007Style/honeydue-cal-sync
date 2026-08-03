import EventKit
import Foundation

/// Writes sanitised meeting blocks to a local calendar via EventKit.
/// Works with any calendar macOS knows about: Google, iCloud, Yahoo, Exchange, etc.
final class EventKitSync {

    let store = EKEventStore()

    /// The title used for every calendar block — set from config before calling create/update.
    var calendarBlockTitle: String = "IBM - BLOCK"

    /// Prefix written into the notes field of every event we manage.
    /// Full format: "honeyDue Calendar Sync | SRC:<sourceEventID>"
    /// — ownership is detected by the prefix, identity by the SRC tag.
    static let ownershipPrefix = "honeyDue Calendar Sync"

    /// Builds the notes string for a given source event ID.
    static func notes(for sourceID: String) -> String {
        "\(ownershipPrefix) | SRC:\(sourceID)"
    }

    /// Returns true if the notes string belongs to us.
    static func isOwned(_ notes: String?) -> Bool {
        notes?.hasPrefix(ownershipPrefix) ?? false
    }

    /// Extracts the source event ID from our notes string, or nil if not present/parseable.
    static func sourceID(from notes: String?) -> String? {
        guard let n = notes, n.hasPrefix(ownershipPrefix) else { return nil }
        guard let range = n.range(of: "SRC:") else { return nil }
        let id = String(n[range.upperBound...])
        return id.isEmpty ? nil : id
    }

    // MARK: - Permission

    /// Request calendar access. Must be called before any other method.
    /// Full access (read + write) is required so we can scan for owned events
    /// to prevent duplicates and perform block-title rename sweeps.
    func requestAccess() async throws {
        if #available(macOS 14.0, *) {
            try await store.requestFullAccessToEvents()
        } else {
            let granted = try await store.requestAccess(to: .event)
            guard granted else { throw EventKitError.accessDenied }
        }
    }

    // MARK: - Calendar list

    /// Returns all writable calendars macOS knows about, grouped by account title.
    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }
    }

    /// Find a calendar by its persistent identifier (stored in config).
    func calendar(forID id: String) -> EKCalendar? {
        store.calendar(withIdentifier: id)
    }

    // MARK: - Create

    /// Creates a new sanitised block event. Returns the EKEvent identifier.
    @discardableResult
    func createEvent(meeting: Meeting, calendarID: String) throws -> String {
        guard let cal = store.calendar(withIdentifier: calendarID) else {
            throw EventKitError.calendarNotFound(calendarID)
        }
        let event = EKEvent(eventStore: store)
        event.calendar  = cal
        event.title     = calendarBlockTitle
        event.notes     = Self.notes(for: meeting.id)
        event.startDate = date(from: meeting.startISO)
        event.endDate   = date(from: meeting.endISO)
        // Strip location, attendees, URL — only title + times go through
        event.location  = nil
        event.url       = nil
        try store.save(event, span: .thisEvent, commit: false)
        return event.eventIdentifier
    }

    // MARK: - Update

    func updateEvent(ekEventID: String, meeting: Meeting) throws {
        guard let event = store.event(withIdentifier: ekEventID) else {
            throw EventKitError.eventNotFound(ekEventID)
        }
        event.title     = calendarBlockTitle
        event.notes     = Self.notes(for: meeting.id)
        event.startDate = date(from: meeting.startISO)
        event.endDate   = date(from: meeting.endISO)
        event.location  = nil
        event.url       = nil
        try store.save(event, span: .thisEvent, commit: false)
    }

    // MARK: - Delete

    func deleteEvent(ekEventID: String) throws {
        guard let event = store.event(withIdentifier: ekEventID) else {
            // Already gone — not an error
            return
        }
        try store.remove(event, span: .thisEvent, commit: false)
    }

    // MARK: - Duplicate cleanup via osascript
    // EventKit read access is unavailable under ad-hoc signing, so we use
    // Calendar.app's AppleScript bridge to find and delete duplicate owned blocks.

    /// Deletes duplicate owned events on the target calendar.
    /// Deduplication is by SRC ID — same source event appearing more than once = duplicate.
    /// Two different source events at the same time are NOT duplicates and are both kept.
    /// Returns the number of duplicates removed.
    @discardableResult
    func removeDuplicateOwnedEvents(calendarName: String) -> Int {
        let script = """
        tell application "Calendar"
            set targetCal to first calendar whose name is "\(calendarName)"
            set allEvents to every event of targetCal
            set seen to {}
            set toDelete to {}
            repeat with e in allEvents
                set n to description of e
                if n is not missing value and n starts with "honeyDue Calendar Sync" then
                    -- extract SRC: id from notes
                    set srcKey to n
                    if srcKey is in seen then
                        set end of toDelete to e
                    else
                        set end of seen to srcKey
                    end if
                end if
            end repeat
            repeat with e in toDelete
                delete e
            end repeat
            return count of toDelete
        end tell
        """
        let result = Process()
        result.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        result.arguments = ["-e", script]
        let pipe = Pipe()
        result.standardOutput = pipe
        result.standardError  = pipe
        try? result.run()
        result.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "0"
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    // MARK: - Title-only update (for block rename without a full Meeting update)

    /// Updates the title of a tracked block, preserving the SRC notes tag.
    func updateEventTitleOnly(ekEventID: String, newTitle: String, sourceID: String) throws {
        guard let event = store.event(withIdentifier: ekEventID) else {
            // Event may have been deleted by the user — not an error
            return
        }
        event.title = newTitle
        event.notes = Self.notes(for: sourceID)   // preserve the SRC tag
        try store.save(event, span: .thisEvent, commit: false)
    }

    // MARK: - Commit

    /// Commits all pending create/update/delete operations in one batch.
    func commit() throws {
        try store.commit()
    }

    /// Rolls back any uncommitted changes.
    func rollback() {
        store.reset()
    }

    // MARK: - Date parsing

    private func date(from iso: String) -> Date {
        // Try full ISO-8601 with offset first, then without
        let fullFormatter = ISO8601DateFormatter()
        fullFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fullFormatter.date(from: iso) { return d }

        fullFormatter.formatOptions = [.withInternetDateTime]
        if let d = fullFormatter.date(from: iso) { return d }

        // AppleScript produces local time without offset — parse as local
        let local = DateFormatter()
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        return local.date(from: iso) ?? Date()
    }
}

// MARK: - Errors

enum EventKitError: LocalizedError {
    case accessDenied
    case calendarNotFound(String)
    case eventNotFound(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Enable it in System Settings → Privacy & Security → Calendars."
        case .calendarNotFound(let id):
            return "Target calendar not found (id: \(id)). Re-select it in Settings."
        case .eventNotFound(let id):
            return "Event not found in calendar (id: \(id))."
        }
    }
}
