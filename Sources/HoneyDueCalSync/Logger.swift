import Foundation
import os.log

/// Simple append-only logger that writes to the configured log file path.
final class Logger {

    static let shared = Logger()
    private init() {}

    private let osLog = OSLog(subsystem: "com.honeydue.calsync", category: "general")
    private let queue = DispatchQueue(label: "com.honeydue.calsync.logger")
    private var logURL: URL { AppPaths.logURL }

    // MARK: - Public

    func info(_ message: String)  { write(level: "INFO ", message) }
    func error(_ message: String) { write(level: "ERROR", message) }

    func configure(config: AppConfig) {
        _customLogURL = AppPaths.resolvedLogURL(config: config)
    }

    // MARK: - Private

    private var _customLogURL: URL?
    private var effectiveURL: URL { _customLogURL ?? logURL }

    private func write(level: String, _ message: String) {
        let line = "[\(timestamp())] [\(level)] \(message)\n"
        // Also emit to os_log for Console.app visibility
        os_log("%{public}@", log: osLog, type: level == "ERROR" ? .error : .info, message)
        queue.async { [weak self] in
            guard let self else { return }
            let url = self.effectiveURL
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true)

                // Safety: if log file exceeds 10 MB, delete it and start fresh
                let maxBytes = 10 * 1024 * 1024
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int, size > maxBytes {
                    try? FileManager.default.removeItem(at: url)
                }

                // Load existing lines, strip those older than 10 days, append new line
                var lines: [String] = []
                if FileManager.default.fileExists(atPath: url.path),
                   let existing = try? String(contentsOf: url, encoding: .utf8) {
                    lines = existing.components(separatedBy: "\n")
                }
                let cutoff = Date().addingTimeInterval(-10 * 24 * 60 * 60)
                lines = lines.filter { self.lineIsNewer(than: cutoff, line: $0) }
                lines.append(line.trimmingCharacters(in: .newlines))
                let output = lines.joined(separator: "\n") + "\n"
                try Data(output.utf8).write(to: url, options: .atomic)
            } catch {
                // Can't log the logger failure — just print to stderr
                fputs("Logger write error: \(error)\n", stderr)
            }
        }
    }

    /// Returns true if the line's timestamp is newer than cutoff, or if it has no parseable timestamp (keep it).
    private func lineIsNewer(than cutoff: Date, line: String) -> Bool {
        guard line.hasPrefix("["),
              let end = line.firstIndex(of: "]"),
              let date = timestampParser.date(from: String(line[line.index(after: line.startIndex)..<end]))
        else { return !line.isEmpty }
        return date > cutoff
    }

    private let timestampParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private func timestamp() -> String {
        timestampParser.string(from: Date())
    }
}
