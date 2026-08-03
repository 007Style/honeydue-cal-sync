import EventKit
import Foundation
import CryptoKit

/// Reads calendar events from a macOS Calendar.app calendar via EventKit.
/// Works with any synced calendar — Exchange/Outlook, Google, iCloud, Yahoo, etc.
final class CalendarReader {

    private let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }

    // MARK: - Fetch meetings

    func fetchMeetings(calendarID: String, lookaheadDays: Int) throws -> [Meeting] {
        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            throw CalendarReaderError.calendarNotFound(calendarID)
        }

        let start = Calendar.current.startOfDay(for: Date())
        let end   = start.addingTimeInterval(TimeInterval(lookaheadDays) * 86400)

        let predicate = store.predicateForEvents(withStart: start, end: end,
                                                 calendars: [calendar])

        // Use enumerateEvents instead of events(matching:) — the latter can hang
        // indefinitely on recurring events because it fetches lazily and may
        // trigger network syncs. enumerateEvents is safe and non-blocking.
        var meetings: [Meeting] = []
        store.enumerateEvents(matching: predicate) { event, stop in
            // Skip cancelled occurrences
            guard event.status != .canceled else { return }

            let startISO = self.iso(event.startDate)
            let endISO   = self.iso(event.endDate ?? event.startDate)

            // For recurring events, use startDate in the hash so each occurrence
            // is treated as a distinct event with its own identity.
            let stableID = event.eventIdentifier + startISO
            let hash     = self.sha256(stableID + endISO)

            meetings.append(Meeting(
                id:        stableID,
                title:     event.title ?? "(no title)",
                startISO:  startISO,
                endISO:    endISO,
                hash:      hash,
                ekEventID: nil
            ))
        }
        return meetings
    }

    // MARK: - Helpers

    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f
    }()

    private func iso(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum CalendarReaderError: LocalizedError {
    case calendarNotFound(String)

    var errorDescription: String? {
        switch self {
        case .calendarNotFound(let id):
            return "Source calendar not found (id: \(id)). Re-select it in Settings."
        }
    }
}
