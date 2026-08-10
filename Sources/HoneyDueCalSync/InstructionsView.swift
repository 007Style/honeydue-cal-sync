import AppKit
import SwiftUI

// MARK: - Instructions window presenter

@MainActor
final class InstructionsWindowController {

    static let shared = InstructionsWindowController()
    private var window: NSWindow?
    private init() {}

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "HoneyDue Calendar Sync — Instructions"
        win.contentView = NSHostingView(rootView: InstructionsView())
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = InstructionsWindowDelegate.shared
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    func clear() { window = nil }
}

final class InstructionsWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = InstructionsWindowDelegate()
    private override init() {}
    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in InstructionsWindowController.shared.clear() }
    }
}

// MARK: - Instructions content view

struct InstructionsView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 20) {
                    // Version line
                    Text("HoneyDue Calendar Sync  v1.0.7")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
    
                    section("What Does HoneyDue Calendar Sync Do Anyway? Also, How Do I Use It?") {
                        body("""
                        Great question. You have a work calendar full of meetings, conference calls, and \
                        "blocked time" that your family absolutely does not need to know the details of. \
                        But they DO need to know you're busy — otherwise they'll book dentist appointments, \
                        plan day trips, and wonder why you're glued to your laptop at 2pm.

                        HoneyDue Calendar Sync solves this by reading your work calendar and copying \
                        sanitised time blocks to your personal or family calendar. Every entry gets a \
                        generic title (like "IBM - BLOCK") — no meeting names, no attendees, no location, \
                        no notes. Just the time. Your secrets stay secret. Your family knows you're busy. \
                        Everyone wins.
                        """)
                    }

                    divider()

                    section("Before You Start — The One Requirement") {
                        body("""
                        HoneyDue Calendar Sync works through macOS Calendar.app. It does NOT connect \
                        to Outlook, Google, or any external service directly. For it to see your calendars, \
                        BOTH your work and personal calendars must be added to macOS Calendar.app.
                        """)
                        subsection("Adding your work calendar (IBM / Exchange / M365):")
                        steps([
                            "Open System Settings → Internet Accounts",
                            "Click the + button and choose Microsoft Exchange (or your work account type)",
                            "Enter your work email and follow the sign-in prompts",
                            "Make sure \"Calendars\" is toggled ON for that account",
                            "Open Calendar.app — your work meetings should appear within a few minutes",
                        ])
                        subsection("Adding your personal / family calendar (iCloud, Google, etc.):")
                        steps([
                            "Open System Settings → Internet Accounts",
                            "Your iCloud account is usually already there — confirm \"Calendars\" is ON",
                            "For Google: click + → Google, sign in, enable Calendars",
                            "Open Calendar.app and confirm both calendars are visible in the sidebar",
                        ])
                        body("Once both calendars show up in Calendar.app, HoneyDue Calendar Sync can see them.")
                    }

                    divider()

                    section("Setting It Up") {
                        steps([
                            "Launch HoneyDue Calendar Sync — the bee appears in your menu bar",
                            "The settings window opens automatically on first launch",
                            "Under SOURCE, pick your work calendar from the dropdown (e.g. \"Calendar — IBM\")",
                            "Under TARGET, pick your personal or family calendar (e.g. \"Work — iCloud\")",
                            "Set a Block Title — this is the only text that will appear on every copied event. " +
                                "Something like \"IBM - BLOCK\" or \"Busy\" works well",
                            "Set your Lookahead Days — how far ahead to sync (default 60, max 100)",
                            "Set your Sync Interval — how often to auto-sync (default: every 1 hour)",
                            "Click Save Config",
                            "Click Run Now to do your first sync immediately",
                        ])
                    }

                    divider()

                    section("Features") {

                        subsection("🔄  Automatic Sync")
                        body("""
                        After the first manual run, the app syncs automatically on the interval you set \
                        (1–12 hours). You don't need to do anything — just leave it running in the tray. \
                        The countdown to the next sync is shown in the settings window and the tray menu.
                        """)

                        subsection("▶️  Run Now")
                        body("""
                        Triggers an immediate sync without waiting for the timer. \
                        The button is disabled while a sync is in progress.
                        """)

                        subsection("🔒  Security — Nothing Leaks")
                        body("""
                        Every copied event gets ONLY the Block Title you configured. \
                        No meeting subject, no attendees, no location, no notes, no URL. \
                        Your work details stay on your work calendar. Period.
                        """)

                        subsection("📅  What Gets Synced")
                        body("""
                        All event types are supported: regular meetings, recurring events, \
                        all-day events, multi-day events, and back-to-back meetings. \
                        Events beyond your Lookahead Days window are ignored.
                        """)

                        subsection("✏️  Changes Are Tracked")
                        body("""
                        HoneyDue remembers what it synced last time. If a meeting moves, the block \
                        on your personal calendar moves too. If a meeting is cancelled, the block \
                        is removed. New meetings get new blocks. Nothing goes stale.
                        """)

                        subsection("🗂️  Source and Target Can't Be the Same")
                        body("""
                        The dropdowns are smart — whichever calendar you pick as Source disappears \
                        from the Target list and vice versa. Syncing a calendar to itself would be \
                        a very bad time.
                        """)

                        subsection("🕒  Sync Interval Options")
                        body("15 minutes, 30 minutes, 1 hour (default), 2, 4, 6, 12, or 24 hours.")

                        subsection("📋  Log File")
                        body("""
                        Every sync is logged to a file in: \
                        ~/Library/Application Support/HoneyDueCalSync/run.log\n\
                        Logs are automatically trimmed to the last 10 days and capped at 10 MB. \
                        Click View Log File in the settings window to open it.
                        """)

                        subsection("🚀  Start at Login")
                        body("""
                        Check \"Start automatically when I log in\" to have the app launch silently \
                        every time you log into your Mac. Requires a signed release build to work fully.
                        """)

                        subsection("🐝  Tray Icon")
                        body("""
                        The bee in your menu bar shows a coloured dot indicating sync status:\n\
                        • Grey — never synced yet\n\
                        • Yellow — sync in progress\n\
                        • Green — last sync succeeded\n\
                        • Red — last sync failed (check the log)\n\n\
                        Right-click the bee for a quick menu: last run time, next run countdown, \
                        Show/Hide Window, Run Now, About, and Quit.
                        """)

                        subsection("📦  Batch Mode")
                        body("""
                        For automation nerds: launch with --batch to run a single sync and exit \
                        immediately with no GUI. Perfect for cron jobs or shell scripts.
                        """)
                    }

                    divider()

                    section("Troubleshooting") {
                        subsection("No calendars in the dropdowns")
                        body("""
                        macOS hasn't granted Calendar access yet. Go to System Settings → \
                        Privacy & Security → Calendars and make sure HoneyDue Calendar Sync is allowed. \
                        Then click the ↺ refresh button next to either dropdown.
                        """)

                        subsection("Blocks aren't appearing on my personal calendar")
                        body("""
                        Check that you clicked Save Config before Run Now. Also confirm the target \
                        calendar is writable (some shared/subscribed calendars are read-only).
                        """)

                        subsection("The log says \"Login item register failed\"")
                        body("""
                        This is normal in debug/unsigned builds. It's harmless and can be ignored \
                        until you're running a properly signed release version.
                        """)

                        subsection("macOS says the app can't be opened because it can't be verified")
                        body("""
                        This is a Gatekeeper warning for apps not yet notarized with Apple. \
                        You have two options:\n\n\
                        Option 1 — Right-click the app in Finder → Open → click Open in the dialog. \
                        You only need to do this once.\n\n\
                        Option 2 — Open Terminal and run:\n\
                           xattr -cr /Applications/HoneyDueCalSync.app\n\n\
                        Then double-click the app normally. This permanently removes the quarantine \
                        flag and you won't be prompted again.
                        """)

                        subsection("I see the bee but no window")
                        body("Left-click the bee, or right-click → Show Window.")
                    }

                    divider()

                    Text("Every effort was made to create bug free and useful software. No warranty implied or inferred; use at your own risk!")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)

                    Text("HoneyDue Calendar Sync v1.0.7  •  From the Minds of Daneyand & Bob")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 24)
                }
                .padding(24)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header banner

    private var header: some View {
        ZStack(alignment: .leading) {
            Color(hex: "#1e3a5f")
            HStack(spacing: 12) {
                Rectangle().fill(Color(hex: "#FCD34D")).frame(width: 6)
                Text("🐝")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("HoneyDue Calendar Sync")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#FCD34D"))
                    Text("INSTRUCTIONS & USER GUIDE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(2)
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .frame(height: 72)
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "#1e3a5f"))
            content()
        }
    }

    private func subsection(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .padding(.top, 6)
    }

    private func body(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(Color(NSColor.labelColor))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func steps(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1).")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#1e3a5f"))
                        .frame(width: 20, alignment: .trailing)
                    Text(item)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func divider() -> some View {
        Divider().padding(.vertical, 4)
    }
}
