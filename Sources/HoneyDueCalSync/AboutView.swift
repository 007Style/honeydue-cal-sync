import AppKit
import SwiftUI

/// Small "About" window shown from the tray menu.
struct AboutView: View {

    var body: some View {
        VStack(spacing: 16) {

            // Profile image
            if let img = loadImage() {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("From the Minds of Daneyand & Bob")
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)

            Text("Daneyand@ibm.com")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.escape)
        }
        .padding(24)
        .frame(width: 290)
    }

    private func loadImage() -> NSImage? {
        let bundleName = "HoneyDueCalSync_HoneyDueCalSync.bundle"
        let imageName  = "IMG_2489.JPG"

        // Search all the places the resource bundle can land depending on
        // how the app was launched (packaged .app vs debug SPM run).
        let candidates: [URL] = [
            // Packaged .app: Contents/Resources/<bundle>/image
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/\(bundleName)/\(imageName)"),
            // SPM debug run: resource bundle next to binary
            Bundle.main.bundleURL
                .appendingPathComponent("\(bundleName)/\(imageName)"),
            // Absolute build path used by SPM (debug only, same machine)
            Bundle.main.resourceURL?
                .appendingPathComponent(imageName) ?? URL(fileURLWithPath: ""),
        ]

        for url in candidates {
            if url.path.isEmpty { continue }
            if let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }
}

// MARK: - Window presenter

@MainActor
final class AboutWindowController {

    static let shared = AboutWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "About HoneyDue Calendar Sync"
        win.contentView = NSHostingView(rootView: AboutView())
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = AboutWindowDelegate.shared
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    func clear() {
        window = nil
    }
}

// Clears the stored reference when the window is closed so it can reopen fresh
final class AboutWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = AboutWindowDelegate()
    private override init() {}

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in AboutWindowController.shared.clear() }
    }
}
