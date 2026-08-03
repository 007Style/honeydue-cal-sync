import Foundation

// MARK: - Meeting

/// A single calendar event read from Outlook.
struct Meeting: Codable, Equatable {
    /// Outlook's unique entry ID for this event.
    let id: String
    /// Event title / subject — the only IBM field we keep.
    let title: String
    /// Start datetime in ISO-8601 format with timezone offset.
    let startISO: String
    /// End datetime in ISO-8601 format with timezone offset.
    let endISO: String
    /// SHA-256 hash of id+title+startISO+endISO — used for change detection.
    let hash: String
    /// The EKEvent identifier assigned after first sync (nil until created).
    var ekEventID: String?
}

// MARK: - SyncState

/// The snapshot for a single target calendar, persisted inside StateFile.
struct SyncState: Codable {
    /// Keyed by source event ID.
    var meetings: [String: Meeting]
    /// ISO-8601 timestamp of the last successful sync to this target.
    var lastSyncISO: String?
    /// The blockTitle active when this state was last written.
    var lastBlockTitle: String?

    static let empty = SyncState(meetings: [:], lastSyncISO: nil, lastBlockTitle: nil)
}

// MARK: - StateFile

/// The full on-disk state — holds one SyncState per target calendar ID.
/// This means switching calendars and switching back restores the correct state,
/// so we never lose track of ekEventIDs we already wrote to a given calendar.
struct StateFile: Codable {
    /// Keyed by targetCalendarID.
    var calendars: [String: SyncState]

    static let empty = StateFile(calendars: [:])

    func state(for calendarID: String) -> SyncState {
        calendars[calendarID] ?? .empty
    }

    mutating func setState(_ state: SyncState, for calendarID: String) {
        calendars[calendarID] = state
    }
}

// MARK: - AppConfig

/// User configuration persisted to config.json.
struct AppConfig: Codable {
    /// EKCalendar persistent identifier of the SOURCE calendar (your work/Outlook calendar).
    var sourceCalendarID: String = ""
    /// Display name of the source calendar (shown in UI).
    var sourceCalendarName: String = ""
    var lookaheadDays: Int = 30
    /// The title written to every calendar block — replaces meeting titles entirely.
    var blockTitle: String = "IBM - BLOCK"
    /// EKCalendar persistent identifier of the TARGET calendar (your personal calendar).
    var targetCalendarID: String = ""
    /// Display name of the target calendar (shown in UI).
    var targetCalendarName: String = ""
    var logPath: String = ""
    /// Sync interval in minutes (15, 30, 60, 120, 240, 360, 720, 1440).
    var syncIntervalMinutes: Int = 60
    var launchAtLogin: Bool = true
    var startMinimized: Bool = false

    static let `default` = AppConfig()
}

// MARK: - SyncResult

/// Summary of a completed sync run.
struct SyncResult {
    let created: Int
    let updated: Int
    let deleted: Int
    let error: String?

    var isSuccess: Bool { error == nil }

    var summary: String {
        if let error { return error }
        if created == 0 && updated == 0 && deleted == 0 {
            return "Sync completed — nothing to do"
        }
        return "Sync completed — \(created) new, \(updated) updated, \(deleted) deleted"
    }
}

// MARK: - SyncStatus (stoplight)

enum SyncStatus: Equatable {
    case neverRun
    case running
    case success(SyncResult)
    case failed(String)

    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.neverRun, .neverRun): return true
        case (.running, .running):   return true
        case (.success, .success):   return true
        case (.failed,  .failed):    return true
        default:                     return false
        }
    }

    var dotColor: String {
        switch self {
        case .neverRun:  return "grey"
        case .running:   return "yellow"
        case .success:   return "green"
        case .failed:    return "red"
        }
    }

    var message: String {
        switch self {
        case .neverRun:          return "No sync run yet"
        case .running:           return "Running… please wait"
        case .success(let r):    return r.summary
        case .failed(let msg):   return msg
        }
    }
}

// MARK: - DiffResult

/// The three buckets the diff engine produces.
struct DiffResult {
    let toCreate: [Meeting]
    let toUpdate: [Meeting]
    /// Events that disappeared from Outlook — we need the ekEventID from state to remove them.
    let toDelete: [Meeting]
}

// MARK: - Paths helper

enum AppPaths {
    static var appSupport: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HoneyDueCalSync")
    }

    static var configURL: URL { appSupport.appendingPathComponent("config.json") }
    static var stateURL:  URL { appSupport.appendingPathComponent("state.json") }
    static var logURL:    URL { appSupport.appendingPathComponent("run.log") }

    /// Resolve the effective log URL: use config value if absolute, else fall back to appSupport/run.log
    static func resolvedLogURL(config: AppConfig) -> URL {
        let p = config.logPath.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return logURL }
        let expanded = (p as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return logURL }
        return URL(fileURLWithPath: expanded)
    }
}
