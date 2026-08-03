import AppKit
import Combine

/// Manages the macOS menu bar (tray) icon, status dot, and context menu.
@MainActor
final class TrayController {

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    // Callback when "Run Now" is chosen from the tray menu
    var onRunNow: (() -> Void)?
    // Callback when "Show Window" is chosen
    var onShowWindow: (() -> Void)?
    // Callback when "Hide Window" is chosen
    var onHideWindow: (() -> Void)?

    // MARK: - Setup

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(status: .neverRun)

        StatusState.shared.$syncStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in self?.updateIcon(status: status) }
            .store(in: &cancellables)
    }

    // MARK: - Icon

    private func updateIcon(status: SyncStatus) {
        guard let button = statusItem?.button else { return }
        // Render bee + coloured dot as a simple NSImage composed from SF Symbols
        // (The full SVG icon would require a bundled asset; here we use text + dot for CLI builds)
        let dotChar: String
        let color: NSColor
        switch status {
        case .neverRun:  dotChar = "●"; color = .systemGray
        case .running:   dotChar = "●"; color = .systemYellow
        case .success:   dotChar = "●"; color = .systemGreen
        case .failed:    dotChar = "●"; color = .systemRed
        }

        let attributed = NSMutableAttributedString(string: "🐝")
        let dot = NSAttributedString(string: dotChar,
                                     attributes: [.foregroundColor: color,
                                                  .font: NSFont.systemFont(ofSize: 8)])
        attributed.append(dot)
        button.attributedTitle = attributed
        button.toolTip = "HoneyDue Calendar Sync — \(status.message)"
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            onShowWindow?()
        }
    }

    // MARK: - Context menu

    private func showMenu() {
        let state = StatusState.shared
        let menu = NSMenu()

        // Title (non-clickable)
        menu.addItem(infoItem("HoneyDue Calendar Sync", bold: true))
        menu.addItem(.separator())

        // Last run
        let lastRunText = "Last run:  \(state.lastRunLabel)  \(state.syncStatus == .neverRun ? "" : statusEmoji(state.syncStatus))"
        menu.addItem(infoItem(lastRunText))

        // Next run
        menu.addItem(infoItem("Next run:  \(state.nextRunLabel)"))
        menu.addItem(.separator())

        // Show / Hide window
        let show = NSMenuItem(title: "Show Window", action: #selector(showWindowAction),
                              keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let hide = NSMenuItem(title: "Hide Window", action: #selector(hideWindowAction),
                              keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        // Run Now
        let runNow = NSMenuItem(title: "Run Now", action: #selector(runNowAction),
                                keyEquivalent: "")
        runNow.target = self
        runNow.isEnabled = !state.isRunning
        menu.addItem(runNow)
        menu.addItem(.separator())

        // About
        let about = NSMenuItem(title: "About", action: #selector(aboutAction),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // Remove so left-click works normally next time
    }

    @objc private func showWindowAction() { onShowWindow?() }
    @objc private func hideWindowAction() { onHideWindow?() }
    @objc private func runNowAction()     { onRunNow?() }
    @objc private func aboutAction()      { Task { @MainActor in AboutWindowController.shared.show() } }

    /// Creates a non-selectable, non-greyed info label using a custom NSView.
    private func infoItem(_ text: String, bold: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false

        let font: NSFont = bold
            ? NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            : NSFont.menuFont(ofSize: 0)

        // Custom label view — bypasses macOS grey-out of disabled items
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .labelColor
        label.sizeToFit()

        let container = NSView(frame: NSRect(x: 0, y: 0,
                                             width: label.frame.width + 20,
                                             height: label.frame.height + 8))
        label.frame.origin = NSPoint(x: 10, y: 4)
        container.addSubview(label)
        item.view = container
        return item
    }

    private func statusEmoji(_ status: SyncStatus) -> String {
        switch status {
        case .neverRun: return ""
        case .running:  return "⏳"
        case .success:  return "✓"
        case .failed:   return "✗"
        }
    }
}
