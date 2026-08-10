# 🐝 HoneyDue Calendar Sync

**Version 1.0.6** — Keeping work and home in sync, without the secrets.

> *From the Minds of Daneyand & Bob*

---

## What Is This?

HoneyDue Calendar Sync is a macOS menu bar app that reads your work calendar and copies sanitised time blocks to your personal or family calendar. Every copied event gets only a generic title (like `IBM - BLOCK`) — no meeting names, no attendees, no location, no notes. Your work details stay private. Your family knows you're busy. Everyone wins.

---

## Download

**➡️ [Download HoneyDue-Calendar-Sync-1.0.6.dmg](https://github.com/007Style/honeydue-cal-sync/releases/latest)**

**📊 [Download HoneyDue-CalSync.pptx — Project Presentation](https://github.com/007Style/honeydue-cal-sync/raw/main/build/HoneyDue-CalSync.pptx)**

---

## Requirements

- macOS 13 (Ventura) or later (Apple Silicon or Intel)
- Both your **work calendar** (Exchange / M365 / IBM) and your **personal calendar** (iCloud, Google, etc.) must be added to **macOS Calendar.app** via **System Settings → Internet Accounts** before the app will see them

---

## Installation

1. Download **`HoneyDue-Calendar-Sync-1.0.6.dmg`** from the [Releases page](https://github.com/007Style/honeydue-cal-sync/releases/latest)
2. Open the DMG
3. Drag **HoneyDueCalSync** into your **Applications** folder
4. Launch the app — the 🐝 bee appears in your menu bar

---

## First Launch — Gatekeeper Warning

Because this app is not notarized through Apple's paid developer program, macOS may show:

> *"HoneyDueCalSync can't be opened because Apple cannot check it for malicious software."*

**You only need to do this once. Two options:**

### Option 1 — Right-click method (no Terminal needed)
1. Find **HoneyDueCalSync.app** in your Applications folder
2. Right-click (or Control-click) → choose **Open**
3. Click **Open** in the dialog
4. The app launches normally from this point forward

### Option 2 — Terminal method (one command, permanent)
```bash
xattr -cr /Applications/HoneyDueCalSync.app
```
Then double-click the app normally. Quarantine flag permanently removed.

---

## Before You Start — One Requirement

HoneyDue Calendar Sync works through **macOS Calendar.app**. It does not connect to Outlook, Google, or any external service directly. Both calendars must be in Calendar.app first.

### Adding your work calendar (IBM / Exchange / M365)
1. Open **System Settings → Internet Accounts**
2. Click **+** → choose **Microsoft Exchange**
3. Enter your work email and follow the sign-in prompts
4. Ensure **Calendars** is toggled ON
5. Open Calendar.app — your work meetings appear within a few minutes

### Adding your personal calendar (iCloud, Google, etc.)
1. Open **System Settings → Internet Accounts**
2. iCloud is usually already there — confirm **Calendars** is ON
3. For Google: click **+** → **Google** → sign in → enable Calendars
4. Confirm both calendars are visible in Calendar.app's sidebar

---

## Quick Setup

1. Launch the app — the settings window opens automatically on first run
2. Under **SOURCE**, pick your work calendar (e.g. `Calendar — IBM`)
3. Under **TARGET**, pick your personal/family calendar (e.g. `Work — iCloud`)
4. Set a **Block Title** — the only text shown on copied events (e.g. `IBM - BLOCK`)
5. Set **Lookahead Days** — how far ahead to sync (default: 60, max: 100)
6. Set **Sync Interval** — how often to auto-sync (default: every 1 hour)
7. Click **Save Config**
8. Click **Run Now** to sync immediately

The app auto-syncs on your chosen interval. Leave it running in the tray and forget about it.

---

## Features

| Feature | Details |
|---|---|
| 🔒 **Zero data leakage** | Only the Block Title, start time, and end time are copied — nothing else |
| 🔄 **Change tracking** | Moved meetings update their block; cancelled meetings remove their block |
| 📅 **All event types** | Regular, recurring, all-day, multi-day, and back-to-back events all work |
| ⏱ **Auto-sync timer** | 15 min, 30 min, 1 h, 2 h, 4 h, 6 h, 12 h, or 24 h intervals |
| 🐝 **Tray icon** | Bee + colour-coded status dot (grey/yellow/green/red) |
| 📋 **Log file** | Auto-rotating log in `~/Library/Application Support/HoneyDueCalSync/run.log` (10-day / 10 MB cap) |
| 🚀 **Start at login** | Optional launch on Mac login (requires signed build) |
| 📦 **Batch mode** | `--batch` flag for scripted one-shot syncs with no GUI |

### Tray Icon Status

| Dot | Meaning |
|---|---|
| ⚫ Grey | App running, no sync yet |
| 🟡 Yellow | Sync in progress |
| 🟢 Green | Last sync succeeded |
| 🔴 Red | Last sync failed — check the log |

Right-click the bee for: last run timestamp, next run countdown, Show/Hide Window, Run Now, About, Quit.

---

## Troubleshooting

**No calendars in the dropdowns**
> macOS hasn't granted Calendar access yet. Go to **System Settings → Privacy & Security → Calendars** and enable HoneyDue Calendar Sync. Then click the ↺ refresh button next to either dropdown.

**Blocks aren't appearing on my personal calendar**
> Confirm you clicked **Save Config** before **Run Now**. Also check that the target calendar is writable (some shared/subscribed calendars are read-only).

**The log says "Login item register failed"**
> Normal in unsigned/debug builds. Harmless — can be ignored.

**macOS says the app can't be verified**
> See [First Launch — Gatekeeper Warning](#first-launch--gatekeeper-warning) above.

**I see the bee but no window**
> Left-click the bee, or right-click → **Show Window**.

---

## Building From Source

### Prerequisites
- macOS 13+ with Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Clone & Build
```bash
git clone https://github.com/007Style/honeydue-cal-sync.git
cd honeydue-cal-sync

# Debug build (fast iteration)
swift build

# Run debug build
open .build/debug/HoneyDueCalSync

# Run unit tests
swift test

# Release build + DMG (runs tests first, aborts on failure)
./build.sh
```

Output from `./build.sh`:
- `build/HoneyDueCalSync.app` — signed .app bundle
- `build/HoneyDue-Calendar-Sync-1.0.6.dmg` — drag-to-install disk image

### Check the log
```bash
cat ~/Library/Application\ Support/HoneyDueCalSync/run.log
```

---

## Project Structure

```
honeydue-cal-sync/
├── Package.swift                        # Swift Package Manager manifest
├── build.sh                             # Release build + DMG packaging script
├── HoneyDueCalSync.entitlements         # Hardened runtime entitlements
├── Sources/HoneyDueCalSync/
│   ├── main.swift                       # Entry point
│   ├── Models.swift                     # Meeting, SyncState, AppConfig, SyncStatus
│   ├── CalendarReader.swift             # Reads events from source calendar via EventKit
│   ├── EventKitSync.swift               # Writes sanitised blocks to target calendar
│   ├── DiffEngine.swift                 # Compare source events vs last snapshot
│   ├── SyncEngine.swift                 # Orchestration: read → diff → write → commit → save
│   ├── AppConfig.swift                  # ConfigManager: load/save/validate config.json
│   ├── StatusState.swift                # Observable sync state (stoplight, counters)
│   ├── TrayController.swift             # NSStatusItem + tray context menu
│   ├── SettingsView.swift               # SwiftUI settings window
│   ├── InstructionsView.swift           # In-app instructions/user guide
│   ├── AboutView.swift                  # About window
│   ├── AppDelegate.swift                # App lifecycle, tray, timer, login item
│   ├── Logger.swift                     # Rotating log file writer
│   ├── Info.plist                       # Bundle ID + Calendar usage description
│   └── Resources/
│       └── IMG_2489.JPG                 # Author photo (About window)
├── Tests/HoneyDueCalSyncTests/
│   ├── DiffEngineTests.swift            # 7 tests — new/changed/deleted/unchanged/mixed
│   ├── AppConfigTests.swift             # 12 tests — all config validation rules
│   └── ModelsTests.swift                # 16 tests — JSON round-trips, SyncResult, AppPaths
├── assets/
│   ├── icon.svg                         # App icon source
│   └── banner.svg                       # GUI banner source
├── build/
│   ├── HoneyDue-Calendar-Sync-1.0.6.dmg # Drag-to-install disk image
│   └── HoneyDue-CalSync.pptx            # Project presentation (downloadable)
├── DESIGN.md                            # Full design document and architecture reference
└── GOOGLE_SETUP.md                      # Legacy OAuth guide (no longer needed — kept for reference)
```

**No third-party dependencies.** Everything is macOS SDK: `EventKit`, `AppKit`, `SwiftUI`, `ServiceManagement`, `CryptoKit`, `Foundation`.

---

## Unit Tests

35 tests across 3 suites (pure logic — no EventKit required):

| Suite | Tests | Coverage |
|---|---|---|
| `DiffEngineTests` | 7 | New, unchanged, changed, deleted, ekEventID forwarding, mixed batch, empty |
| `AppConfigTests` | 12 | Calendar IDs, lookahead bounds, all 8 sync intervals, block title validation |
| `ModelsTests` | 16 | JSON round-trips for all model types, SyncResult summaries, AppPaths resolution |

```bash
swift test
```

---

## Architecture Notes

- **EventKit only** — both source (work) and target (personal) calendars are accessed via macOS EventKit/Calendar.app. No Outlook AppleScript (broken in Outlook 16.80+), no Google OAuth.
- **State tracking** — after each successful sync, a `state.json` snapshot is written. The diff engine compares current events against this snapshot to detect creates, updates, and deletes.
- **Ownership marker** — every block created by the app carries `"honeyDue Calendar Sync"` in its notes field (invisible to the user). This allows the app to identify and manage its own events.
- **Atomic commits** — all EventKit changes are batched and committed only after all operations succeed. On any failure, changes roll back and state is not updated.

See [`DESIGN.md`](DESIGN.md) for the full architecture reference.

---

## All App Files in One Place

All generated files live in `~/Library/Application Support/HoneyDueCalSync/`:

| File | Description |
|---|---|
| `config.json` | User configuration |
| `state.json` | Last sync snapshot |
| `run.log` | Log output (auto-rotating) |

---

## Disclaimer

Every effort was made to create bug-free and useful software.  
No warranty implied or inferred; use at your own risk.

---

*From the Minds of Daneyand & Bob!*  
[daneyand@ibm.com](mailto:daneyand@ibm.com)
