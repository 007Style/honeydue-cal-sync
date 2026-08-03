import Foundation
import EventKit

/// Loads and saves AppConfig to/from the Application Support directory.
final class ConfigManager {

    static let shared = ConfigManager()
    private init() {}

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    // MARK: - Load / Save

    func load() -> AppConfig {
        let url = AppPaths.configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? decoder.decode(AppConfig.self, from: data)
        else { return .default }
        return sanitise(config)
    }

    /// Clamp / sanitise all numeric and string fields so a hand-edited config.json
    /// can never drive the app into an invalid state.
    private func sanitise(_ raw: AppConfig) -> AppConfig {
        var c = raw
        // Clamp lookahead days 1–100
        if !(1...100).contains(c.lookaheadDays) {
            Logger.shared.info("Config sanitised: lookaheadDays \(c.lookaheadDays) out of range — reset to 30")
            c.lookaheadDays = 30
        }
        // Clamp sync interval to valid set: 1 (test) or one of the fixed options
        let validIntervals = Set([1, 15, 30, 60, 120, 240, 360, 720, 1440])
        if !validIntervals.contains(c.syncIntervalMinutes) {
            Logger.shared.info("Config sanitised: syncIntervalMinutes \(c.syncIntervalMinutes) invalid — reset to 60")
            c.syncIntervalMinutes = 60
        }
        // Trim block title — if blank after trimming, reset to default
        let trimmedTitle = c.blockTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            Logger.shared.info("Config sanitised: blockTitle was empty — reset to default")
            c.blockTitle = AppConfig.default.blockTitle
        } else {
            // Cap block title at 64 characters
            if trimmedTitle.count > 64 {
                Logger.shared.info("Config sanitised: blockTitle truncated to 64 characters")
                c.blockTitle = String(trimmedTitle.prefix(64))
            } else {
                c.blockTitle = trimmedTitle
            }
        }
        // logPath must be absolute or empty — reject relative paths
        let logPath = c.logPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !logPath.isEmpty {
            let expanded = (logPath as NSString).expandingTildeInPath
            if !expanded.hasPrefix("/") {
                Logger.shared.info("Config sanitised: logPath '\(logPath)' is not absolute — reset to default")
                c.logPath = ""
            }
        }
        return c
    }

    @discardableResult
    func save(_ config: AppConfig) -> Bool {
        do {
            try FileManager.default.createDirectory(at: AppPaths.appSupport,
                                                    withIntermediateDirectories: true)
            let data = try encoder.encode(config)
            try data.write(to: AppPaths.configURL, options: .atomic)
            return true
        } catch {
            Logger.shared.error("ConfigManager.save failed: \(error)")
            return false
        }
    }

    // MARK: - Validation

    struct ValidationError: Error {
        let field: String
        let message: String
    }

    func validate(_ config: AppConfig) throws {
        // Source calendar ID present
        guard !config.sourceCalendarID.isEmpty else {
            throw ValidationError(field: "sourceCalendarID",
                                  message: "Select a source calendar to read from.")
        }
        // Target calendar ID present
        guard !config.targetCalendarID.isEmpty else {
            throw ValidationError(field: "targetCalendarID",
                                  message: "Select a target calendar to sync events into.")
        }
        // Source ≠ target
        guard config.sourceCalendarID != config.targetCalendarID else {
            throw ValidationError(field: "sourceCalendarID",
                                  message: "Source and target calendars must be different.")
        }
        // Lookahead days in range
        guard (1...100).contains(config.lookaheadDays) else {
            throw ValidationError(field: "lookaheadDays",
                                  message: "Lookahead days must be 1–100.")
        }
        // Sync interval valid
        let validIntervals = Set([1, 15, 30, 60, 120, 240, 360, 720, 1440])
        guard validIntervals.contains(config.syncIntervalMinutes) else {
            throw ValidationError(field: "syncIntervalMinutes",
                                  message: "Sync interval is invalid.")
        }
        // Block title not empty
        guard !config.blockTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError(field: "blockTitle",
                                  message: "Enter a block title (e.g. IBM - BLOCK).")
        }
        // Log file path absolute if set
        let logPath = config.logPath.trimmingCharacters(in: .whitespaces)
        if !logPath.isEmpty {
            let expanded = (logPath as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/") else {
                throw ValidationError(field: "logPath",
                                      message: "Log file path must be an absolute path.")
            }
            let logDir = (expanded as NSString).deletingLastPathComponent
            guard FileManager.default.fileExists(atPath: logDir) else {
                throw ValidationError(field: "logPath",
                                      message: "Log file directory does not exist.")
            }
        }
    }

    /// Checks that the configured calendar IDs actually exist in the given EventKit store.
    /// Called at sync time (requires EventKit access to have been granted already).
    func validateCalendars(config: AppConfig, store: EKEventStore) {
        let all = store.calendars(for: .event)
        let ids = Set(all.map { $0.calendarIdentifier })
        if !config.sourceCalendarID.isEmpty, !ids.contains(config.sourceCalendarID) {
            Logger.shared.error(
                "Config warning: source calendar '\(config.sourceCalendarName)' (ID: \(config.sourceCalendarID)) " +
                "was not found in Calendar.app — it may have been removed or renamed.")
        }
        if !config.targetCalendarID.isEmpty, !ids.contains(config.targetCalendarID) {
            Logger.shared.error(
                "Config warning: target calendar '\(config.targetCalendarName)' (ID: \(config.targetCalendarID)) " +
                "was not found in Calendar.app — it may have been removed or renamed.")
        }
    }
}
