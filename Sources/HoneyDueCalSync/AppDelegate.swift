import AppKit
import SwiftUI
import ServiceManagement
import Combine

/// Application entry point — owns the tray, window, sync engine, and timer.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Components

    /// Bare init — nonisolated so main.swift can call it before the run loop starts.
    /// All real work happens in applicationDidFinishLaunching on the main thread.
    nonisolated override init() {
        super.init()
    }

    // Initialised in applicationDidFinishLaunching (requires MainActor context)
    private var tray: TrayController!
    private nonisolated(unsafe) let syncEngine = SyncEngine()
    private var settingsWindow: NSWindow?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var config: AppConfig = ConfigManager.shared.load()

    /// True when launched with -t: enables 1-minute interval for testing.
    let testingMode: Bool = CommandLine.arguments.contains("-t")

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — we are a tray-only app
        NSApp.setActivationPolicy(.accessory)

        // Set up tray (must be on MainActor)
        tray = TrayController()
        tray.install()
        tray.onRunNow     = { [weak self] in Task { @MainActor [weak self] in await self?.runSync() } }
        tray.onShowWindow = { [weak self] in Task { @MainActor [weak self] in self?.showSettingsWindow() } }
        tray.onHideWindow = { [weak self] in self?.hideWindow() }

        // If not in testing mode and the 1-minute test interval was saved, reset to 1 hour
        if !testingMode && config.syncIntervalMinutes == 1 {
            config.syncIntervalMinutes = 60
            ConfigManager.shared.save(config)
        }

        // Apply log path from config
        Logger.shared.configure(config: config)

        // Apply login item state
        applyLoginItem(enabled: config.launchAtLogin)

        // Batch mode: --batch flag → run sync and exit
        if CommandLine.arguments.contains("--batch") {
            Task { @MainActor [weak self] in
                await self?.runSync()
                try? await Task.sleep(nanoseconds: 500_000_000) // flush logger
                NSApp.terminate(nil)
            }
            return
        }

        // Interactive: show window (unless start minimized is set)
        if !config.startMinimized {
            showSettingsWindow()
        }
        // Do NOT auto-run on startup — first sync is on timer expiry or Run Now button

        // Start countdown timer
        scheduleTimer()

        // Wake from sleep observer — reschedules missed syncs after lid open
        registerSleepWakeObserver()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return false
    }

    // MARK: - Settings window

    func showSettingsWindow() {
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        var view = SettingsView()
        view.testingMode = testingMode
        view.onSave = { [weak self] newConfig in
            guard let self else { return }
            self.config = newConfig
            Logger.shared.configure(config: newConfig)
            self.applyLoginItem(enabled: newConfig.launchAtLogin)
            self.rescheduleTimer()
        }
        view.onRunNow     = { [weak self] in Task { @MainActor [weak self] in await self?.runSync() } }
        view.onHideToTray = { [weak self] in self?.hideWindow() }
        view.onViewLog    = { [weak self] in self?.openLogFile() }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "HoneyDue Calendar Sync"
        win.contentView = NSHostingView(rootView: view.environmentObject(StatusState.shared))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }

    private func hideWindow() {
        settingsWindow?.orderOut(nil)
    }

    // MARK: - Sync

    func runSync() async {
        let state = StatusState.shared
        guard !state.isRunning else { return }

        // Guard: validate config before doing anything — log and bail if not set up
        let cfg = config
        do {
            try ConfigManager.shared.validate(cfg)
        } catch let e as ConfigManager.ValidationError {
            Logger.shared.info("Sync skipped — configuration incomplete: \(e.message)")
            return
        } catch {
            Logger.shared.info("Sync skipped — configuration invalid: \(error.localizedDescription)")
            return
        }

        state.isRunning = true
        state.syncStatus = .running

        do {
            let result = try await syncEngine.run(config: cfg)
            state.syncStatus = .success(result)
            state.lastRunDate = Date()
        } catch let e as EventKitError {
            state.syncStatus = .failed("Sync failed — \(e.localizedDescription)")
            state.lastRunDate = Date()
            Logger.shared.error("Sync failed: \(e)")
        } catch {
            state.syncStatus = .failed("Sync failed — \(error.localizedDescription)")
            state.lastRunDate = Date()
            Logger.shared.error("Sync failed: \(error)")
        }

        state.isRunning = false
        rescheduleTimer()
    }

    // MARK: - Timer

    private func scheduleTimer() {
        // Use the user's configured interval as-is (15, 30, 60 … 1440 min).
        // Testing mode (-t) allows an additional 1-min value via the settings UI.
        let interval = TimeInterval(config.syncIntervalMinutes * 60)
        let nextRun = Date().addingTimeInterval(interval)
        StatusState.shared.nextRunDate = nextRun

        // Use a repeating timer so macOS wake-from-sleep fires it if the interval
        // was missed while the lid was closed. We check the scheduled time on each
        // tick and only run if it's actually due.
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let due = StatusState.shared.nextRunDate, Date() >= due else { return }
                await self.runSync()
            }
        }
        // Ensure the timer fires even when the app is idle / no UI events
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        scheduleTimer()
    }

    // MARK: - Sleep / wake handling

    private func registerSleepWakeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                Logger.shared.info("System woke from sleep — checking sync schedule")
                // If next run time has already passed, fire immediately
                if let due = StatusState.shared.nextRunDate, Date() >= due {
                    Logger.shared.info("Sync overdue after sleep — running now")
                    await self.runSync()
                }
            }
        }
    }

    // MARK: - Login item

    private func applyLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.shared.error("Login item \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    // MARK: - Log viewer

    private func openLogFile() {
        let url = AppPaths.logURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            let alert = NSAlert()
            alert.messageText = "No log file yet"
            alert.informativeText = "No log file yet — run a sync first."
            alert.runModal()
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let win = notification.object as? NSWindow, win === settingsWindow {
            settingsWindow = nil
        }
    }
}
