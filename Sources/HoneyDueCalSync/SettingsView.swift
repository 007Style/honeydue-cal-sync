import SwiftUI
import AppKit
import EventKit

/// The main settings and status window.
struct SettingsView: View {

    @ObservedObject private var statusState = StatusState.shared
    @State private var config: AppConfig = ConfigManager.shared.load()
    @State private var availableCalendars: [EKCalendar] = []
    @State private var validationError: String? = nil
    @State private var isLoadingCalendars = false

    // Callbacks wired up by AppDelegate
    var onSave: ((AppConfig) -> Void)?
    var onRunNow: (() -> Void)?
    var onHideToTray: (() -> Void)?
    var onViewLog: (() -> Void)?

    // Set to true when launched with -t (testing mode — adds 1-minute interval)
    var testingMode: Bool = false

    private var intervalOptions: [(label: String, minutes: Int)] {
        var opts: [(label: String, minutes: Int)] = []
        if testingMode {
            opts.append((label: "Every 1 minute (testing)", minutes: 1))
        }
        opts += [
            (label: "Every 15 minutes", minutes: 15),
            (label: "Every 30 minutes", minutes: 30),
            (label: "Every 1 hour",     minutes: 60),
            (label: "Every 2 hours",    minutes: 120),
            (label: "Every 4 hours",    minutes: 240),
            (label: "Every 6 hours",    minutes: 360),
            (label: "Every 12 hours",   minutes: 720),
            (label: "Every 24 hours",   minutes: 1440),
        ]
        return opts
    }

    // Calendars available for source picker (excludes currently selected target)
    private var sourceCalendars: [EKCalendar] {
        availableCalendars.filter { $0.calendarIdentifier != config.targetCalendarID }
    }

    // Calendars available for target picker (excludes currently selected source)
    private var targetCalendars: [EKCalendar] {
        availableCalendars.filter { $0.calendarIdentifier != config.sourceCalendarID }
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            VStack(alignment: .leading, spacing: 0) {
                form
                Divider().padding(.horizontal, 16)
                actionBar
                statusBar
                Divider().padding(.horizontal, 16)
                bottomBar
            }
        }
        .frame(width: 660, height: 680)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { fetchCalendars() }
    }

    // MARK: - Banner

    private var banner: some View {
        ZStack(alignment: .leading) {
            Color(hex: "#1e3a5f")
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(hex: "#FCD34D"))
                    .frame(width: 6)
                Text("🐝")
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 2) {
                    Text("HoneyDue")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "#FCD34D"))
                    Text("CALENDAR SYNC")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(2)
                    Text("Keeping work and home in sync — without the secrets.")
                        .font(.system(size: 11, weight: .light).italic())
                        .foregroundColor(Color(hex: "#93c5fd"))
                }
                Spacer()
                if testingMode {
                    Text("TESTING MODE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#FCD34D"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#FCD34D"), lineWidth: 1))
                        .padding(.trailing, 12)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(height: 90)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {

            sectionHeader("SOURCE  (read from)")

            // Source calendar
            field(label: "Source Calendar") {
                VStack(alignment: .leading, spacing: 3) {
                    calendarPicker(selection: $config.sourceCalendarID,
                                   nameBinding: $config.sourceCalendarName,
                                   calendars: sourceCalendars)
                    Text("The work calendar containing your IBM meetings")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Lookahead days
            field(label: "Lookahead Days") {
                HStack {
                    Stepper(value: $config.lookaheadDays, in: 1...100) {
                        Text("\(config.lookaheadDays) day\(config.lookaheadDays == 1 ? "" : "s")")
                    }
                    Spacer()
                }
            }

            sectionHeader("TARGET  (write to)")

            // Target calendar
            field(label: "Target Calendar") {
                VStack(alignment: .leading, spacing: 3) {
                    calendarPicker(selection: $config.targetCalendarID,
                                   nameBinding: $config.targetCalendarName,
                                   calendars: targetCalendars)
                    Text("The personal calendar that receives the sanitised blocks")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Block title
            field(label: "Block Title") {
                VStack(alignment: .leading, spacing: 3) {
                    TextField("IBM - BLOCK", text: $config.blockTitle)
                        .textFieldStyle(.roundedBorder)
                    Text("The name shown on every calendar entry — no meeting details are copied")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            sectionHeader("OPTIONS")

            // Log file
            field(label: "Log File") {
                HStack {
                    TextField(AppPaths.logURL.path, text: $config.logPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browseFile(binding: $config.logPath, savePanel: true) }
                }
            }

            // Sync interval
            field(label: "Sync Interval") {
                Picker("", selection: $config.syncIntervalMinutes) {
                    ForEach(intervalOptions, id: \.minutes) { opt in
                        Text(opt.label).tag(opt.minutes)
                    }
                }
                .frame(maxWidth: 220)
            }

            // Launch at login + Start minimized — same line
            HStack(spacing: 12) {
                Spacer().frame(width: 168)
                Toggle("Start automatically when I log in", isOn: $config.launchAtLogin)
                    .font(.system(size: 13))
                    .fixedSize()
                Text("  ||  ")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Toggle("Start minimized to tray", isOn: $config.startMinimized)
                    .font(.system(size: 13))
                    .fixedSize()
            }
        }
        .padding(16)
    }

    // MARK: - Shared calendar picker

    @ViewBuilder
    private func calendarPicker(selection: Binding<String>,
                                 nameBinding: Binding<String>,
                                 calendars: [EKCalendar]) -> some View {
        HStack {
            if isLoadingCalendars {
                ProgressView().scaleEffect(0.7)
                Text("Loading calendars…")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            } else if availableCalendars.isEmpty {
                Text("No calendars found — check Calendar access in System Settings")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            } else {
                Picker("", selection: selection) {
                    Text("Select a calendar…").tag("")
                    ForEach(calendars, id: \.calendarIdentifier) { cal in
                        Text("\(cal.title)  —  \(cal.source.title)")
                            .tag(cal.calendarIdentifier)
                    }
                }
                .frame(maxWidth: .infinity)
                .onChange(of: selection.wrappedValue) { newID in
                    nameBinding.wrappedValue = availableCalendars
                        .first { $0.calendarIdentifier == newID }?.title ?? ""
                }
            }
            Button("↺") { fetchCalendars() }
                .help("Refresh calendar list")
        }
    }

    // MARK: - Validation error banner

    @ViewBuilder
    private var validationBanner: some View {
        if let err = validationError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(err)
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack {
            validationBanner
            Spacer()
            Button("Save Config") { saveConfig() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Run Now") {
                saveConfig()
                onRunNow?()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(statusState.isRunning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Last Run:")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                Text(statusState.lastRunLabel)
                    .font(.system(size: 13))
            }
            HStack(spacing: 6) {
                Text("Status:")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                stoplightDot(statusState.syncStatus)
                Text(statusState.syncStatus.message)
                    .font(.system(size: 13))
                    .foregroundColor(statusColor(statusState.syncStatus))
            }
            HStack(spacing: 6) {
                Text("Next Run:")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                Text(statusState.nextRunLabel)
                    .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Button("View Log File") { onViewLog?() }
            Button("View Instructions") {
                Task { @MainActor in InstructionsWindowController.shared.show() }
            }
            Spacer()
            Button("Hide to Tray") { onHideToTray?() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func field<Content: View>(label: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 168, alignment: .trailing)
                .foregroundColor(.primary)
                .font(.system(size: 13))
            content()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(1)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func stoplightDot(_ status: SyncStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 10, height: 10)
    }

    private func statusColor(_ status: SyncStatus) -> Color {
        switch status {
        case .neverRun: return .gray
        case .running:  return .yellow
        case .success:  return .green
        case .failed:   return .red
        }
    }

    // MARK: - Actions

    private func saveConfig() {
        do {
            try ConfigManager.shared.validate(config)
            validationError = nil
            ConfigManager.shared.save(config)
            Logger.shared.configure(config: config)
            onSave?(config)
        } catch let e as ConfigManager.ValidationError {
            validationError = e.message
        } catch {
            validationError = error.localizedDescription
        }
    }

    private func fetchCalendars() {
        isLoadingCalendars = true
        let store = EKEventStore()
        Task {
            do {
                if #available(macOS 14.0, *) {
                    try await store.requestFullAccessToEvents()
                } else {
                    _ = try await store.requestAccess(to: .event)
                }
                let all = store.calendars(for: .event)
                    .sorted { "\($0.source.title)\($0.title)" < "\($1.source.title)\($1.title)" }
                await MainActor.run {
                    self.availableCalendars = all
                    self.isLoadingCalendars = false
                    // Clear saved IDs if they no longer exist
                    if !self.config.sourceCalendarID.isEmpty,
                       !all.contains(where: { $0.calendarIdentifier == self.config.sourceCalendarID }) {
                        self.config.sourceCalendarID = ""
                        self.config.sourceCalendarName = ""
                    }
                    if !self.config.targetCalendarID.isEmpty,
                       !all.contains(where: { $0.calendarIdentifier == self.config.targetCalendarID }) {
                        self.config.targetCalendarID = ""
                        self.config.targetCalendarName = ""
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCalendars = false
                    self.validationError = "Calendar access denied. Enable in System Settings → Privacy & Security → Calendars."
                }
            }
        }
    }

    private func browseFile(binding: Binding<String>, savePanel: Bool = false) {
        if savePanel {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = URL(fileURLWithPath: binding.wrappedValue).lastPathComponent
            if panel.runModal() == .OK, let url = panel.url {
                binding.wrappedValue = url.path
            }
        } else {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            if panel.runModal() == .OK, let url = panel.url {
                binding.wrappedValue = url.path
            }
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
