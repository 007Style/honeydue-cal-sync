import Foundation
import CryptoKit

/// Reads calendar events from Microsoft Outlook on macOS via AppleScript.
final class OutlookReader {

    // MARK: - Public API

    /// Fetch all events in the rolling window [today, today + lookaheadDays].
    func fetchMeetings(calendar: String, lookaheadDays: Int) throws -> [Meeting] {
        let script = buildScript(calendar: calendar, lookaheadDays: lookaheadDays)
        let output = try runAppleScript(script)
        return try parse(output: output)
    }

    /// Return all calendar names visible in Outlook.
    func fetchCalendarNames() throws -> [String] {
        let script = """
        tell application "Microsoft Outlook"
            set calNames to {}
            repeat with cal in calendars
                set end of calNames to name of cal
            end repeat
            return calNames
        end tell
        """
        let output = try runAppleScript(script)
        // AppleScript returns comma-separated list
        return output
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - AppleScript builder

    private func buildScript(calendar: String, lookaheadDays: Int) -> String {
        // AppleScript date arithmetic — build start/end bounds in AppleScript
        return """
        tell application "Microsoft Outlook"
            set startBound to current date
            set startBound to startBound - (time of startBound)
            set endBound to startBound + (\(lookaheadDays) * days)
            set calName to "\(calendar.replacingOccurrences(of: "\"", with: "\\\""))"
            set results to {}
            set targetCal to missing value
            repeat with cal in calendars
                if name of cal is calName then
                    set targetCal to cal
                    exit repeat
                end if
            end repeat
            if targetCal is missing value then
                error "Calendar not found: " & calName
            end if
            set evts to calendar events of targetCal
            repeat with evt in evts
                set evtStart to start time of evt
                set evtEnd to end time of evt
                if evtStart >= startBound and evtStart <= endBound then
                    set evtID to id of evt as string
                    set evtTitle to subject of evt
                    set startStr to my isoDate(evtStart)
                    set endStr to my isoDate(evtEnd)
                    set end of results to evtID & "|" & evtTitle & "|" & startStr & "|" & endStr
                end if
            end repeat
            return results
        end tell

        on isoDate(d)
            set y to year of d as string
            set mo to text -2 thru -1 of ("0" & (month of d as integer) as string)
            set dy to text -2 thru -1 of ("0" & day of d as string)
            set hr to text -2 thru -1 of ("0" & hours of d as string)
            set mn to text -2 thru -1 of ("0" & minutes of d as string)
            set sc to text -2 thru -1 of ("0" & seconds of d as string)
            return y & "-" & mo & "-" & dy & "T" & hr & ":" & mn & ":" & sc
        end isoDate
        """
    }

    // MARK: - Run osascript

    private func runAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw OutlookReaderError.appleScriptFailed(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Parse output

    /// AppleScript returns a comma-separated list of pipe-delimited records.
    /// Each record: "id|title|startISO|endISO"
    private func parse(output: String) throws -> [Meeting] {
        guard !output.isEmpty else { return [] }

        // AppleScript list items are separated by ", " when coerced to string
        // Split on newline first (osascript -e returns one item per line for lists)
        let lines = output
            .components(separatedBy: "\n")
            .flatMap { $0.components(separatedBy: ", ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("|") }

        return lines.compactMap { line -> Meeting? in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 4 else { return nil }
            let id    = parts[0]
            let title = parts[1]
            let start = parts[2]
            let end   = parts[3]
            let hash  = sha256(id + title + start + end)
            return Meeting(id: id, title: title,
                           startISO: start, endISO: end,
                           hash: hash, ekEventID: nil)
        }
    }

    // MARK: - Hash

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum OutlookReaderError: LocalizedError {
    case appleScriptFailed(String)
    case calendarNotFound(String)

    var errorDescription: String? {
        switch self {
        case .appleScriptFailed(let msg): return "AppleScript error: \(msg)"
        case .calendarNotFound(let name): return "Outlook calendar not found: \(name)"
        }
    }
}
