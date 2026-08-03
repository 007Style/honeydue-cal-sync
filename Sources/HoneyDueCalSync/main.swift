import AppKit

// SPM executable entry point — manual wiring (no Info.plist / NSApplicationMain).
// AppDelegate has a nonisolated init() so it can be constructed here synchronously.
// All real setup runs in applicationDidFinishLaunching on the main thread.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
