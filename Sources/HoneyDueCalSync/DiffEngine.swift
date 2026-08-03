import Foundation

/// Compares a fresh list of Outlook meetings against the last saved state snapshot.
final class DiffEngine {

    /// Produces three buckets: events to create, update, or delete on Google Calendar.
    func diff(current: [Meeting], snapshot: SyncState) -> DiffResult {
        let currentByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let snapshotByID = snapshot.meetings

        var toCreate: [Meeting] = []
        var toUpdate: [Meeting] = []
        var toDelete: [Meeting] = []

        // Events in Outlook now
        for (id, meeting) in currentByID {
            if let existing = snapshotByID[id] {
                if existing.hash != meeting.hash {
                    // Changed — carry the EventKit ID forward so we can update the existing event
                    var updated = meeting
                    updated.ekEventID = existing.ekEventID
                    toUpdate.append(updated)
                }
                // else: hash unchanged → skip
            } else {
                // New — not in snapshot
                toCreate.append(meeting)
            }
        }

        // Events in snapshot but no longer in Outlook → delete
        for (id, meeting) in snapshotByID {
            if currentByID[id] == nil {
                toDelete.append(meeting)
            }
        }

        return DiffResult(toCreate: toCreate, toUpdate: toUpdate, toDelete: toDelete)
    }
}
