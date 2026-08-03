import Foundation
import Combine

/// Shared observable state — owned by AppDelegate, observed by both TrayController and SettingsView.
@MainActor
final class StatusState: ObservableObject {

    static let shared = StatusState()
    private init() {
        // Tick every 30 seconds so the countdown label stays live in the GUI
        tickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick += 1 }
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    @Published var syncStatus: SyncStatus = .neverRun
    @Published var lastRunDate: Date? = nil
    @Published var nextRunDate: Date? = nil
    @Published var isRunning: Bool = false
    /// Incremented every 30 s — forces SwiftUI to re-evaluate computed label properties.
    @Published private var tick: Int = 0

    private var tickTimer: Timer?

    // Countdown string e.g. "in 34 minutes"
    var nextRunLabel: String {
        _ = tick // subscribe to tick so SwiftUI re-renders on each tick
        guard let next = nextRunDate else { return "—" }
        let diff = next.timeIntervalSinceNow
        if diff <= 0 { return "now" }
        let mins = Int(diff / 60) + 1
        if mins == 1 { return "in 1 minute" }
        return "in \(mins) minutes"
    }

    var lastRunLabel: String {
        guard let last = lastRunDate else { return "Never" }
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy  h:mma"
        return f.string(from: last)
    }
}
