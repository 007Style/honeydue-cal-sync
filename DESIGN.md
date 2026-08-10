# HoneyDue Calendar Sync — Design Document

> This document captures all design decisions made during planning and implementation.
> It is the authoritative reference for any future development session.
> **If context is lost (e.g. chat session ends), start here.**

---

## Purpose

HoneyDue Calendar Sync ("HDCS") is a macOS menu bar (tray) application that reads a work
calendar (e.g. IBM/Exchange via macOS Calendar.app) and syncs sanitised time blocks to a
personal calendar — stripping all confidential details in the process.

The goal is to block off time on a personal calendar so that family/personal commitments
respect work hours, **without exposing any work-specific information about why the user is busy**.
This is a deliberate security requirement, not a preference.

---

## The Name

**HoneyDue Calendar Sync** — the work calendar "dues" get sanitized and sent home.

| Form | Value |
|---|---|
| Display name | HoneyDue Calendar Sync |
| Project folder | `honeydue-cal-sync` |
| Swift module | `HoneyDueCalSync` |
| Bundle ID | `com.honeydue.calsync` |
| Short CLI prefix | `hdcs` |

---

## Core Sanitization Rules

Every event copied from the source calendar is scrubbed as follows:

| Field | Rule |
|---|---|
| **Title** | Replaced with the user-configured **Block Title** (e.g. `IBM - BLOCK`) |
| **Start time** | Copied verbatim |
| **End time** | Copied verbatim (duration preserved) |
| **Description / notes** | Set to `"honeyDue Calendar Sync"` (ownership marker — see below) |
| **Location** | Not written |
| **Attendees** | Not written |
| **URL** | Not written |

**Nothing from the source meeting leaks through — not even the title.**

> **Ownership marker:** Every event HDCS creates carries the fixed string `"honeyDue Calendar Sync"`
> in its notes field. This is the only way the app distinguishes its own events from events the
> user created manually. It enables three safety features: duplicate prevention, block-title
> rename sweeps, and graceful recovery from a cleared state file.

---

## Architecture Decision: EventKit Only (no Outlook AppleScript)

Both source and target calendars are accessed via **macOS EventKit / Calendar.app**.

### Why not Outlook AppleScript?
Outlook 16.80+ (the "new sync engine" / HxStore era) broke the `calendar events` AppleScript
property for Exchange-synced accounts. The property returns 0 events even when Outlook is
fully synced and showing events in its UI. This is a confirmed Microsoft regression with no fix.

### Why EventKit works
The user adds their work account (Exchange/M365/IBM) to **macOS Calendar.app** via System
Settings → Internet Accounts. Calendar.app syncs the work calendar locally. EventKit can
then read those events directly — no Outlook, no AppleScript, no Microsoft APIs needed.

The personal target calendar (iCloud, Google, Yahoo) is also in Calendar.app. So both
source and target are EventKit calendars.

---

## Application Flow

```
App starts
    |
    v
Tray icon appears (bee + status dot)
    |
    v
Settings window opens (unless Start Minimized is set)
    |
    v
On timer expiry OR "Run Now" button:
    |
    v
EventKit.requestFullAccess()
    |
    v
CalendarReader.fetchMeetings(sourceCalendarID, lookaheadDays)
    |
    v
Load state.json (last snapshot)
    |
    v
DiffEngine: compare current vs snapshot
    |
    +--------+-----------+-----------+
    |        |           |           |
   NEW    CHANGED    DELETED    NO CHANGE
    |        |           |           |
  Create   Update     Delete      Skip
  on EK    on EK     from EK
    |        |           |
    +--------+-----------+
    |
    v
EventKit.commit() — only if ALL operations succeeded
    |
    v
Save state.json (only on full success)
    |
    v
Update status dot + GUI stoplight
```

> **Note:** The app does NOT auto-sync on startup. First sync is triggered by
> the timer expiry or the Run Now button only.

---

## Operating Modes

### Interactive Mode (default)
- macOS menu bar tray app — bee icon + coloured status dot
- Settings window opens on launch (unless Start Minimized is checked)
- Run Now button triggers immediate sync in background thread
- Countdown to next scheduled sync shown in GUI and tray menu

### Batch Mode (`--batch` flag)
- For future automation use
- Runs sync once and exits
- No GUI — reads config from Application Support

---

## Sync Window

- Rolling window from today forward by `lookaheadDays` (default 60, configurable 1–365)
- Events outside this window are ignored
- Events that fall out of the window on a subsequent run are **not** deleted from the target calendar

---

## State Tracking (state.json)

After each successful sync, a snapshot is written to `state.json`.

Each entry contains:
- Source event unique ID (EKEvent.eventIdentifier)
- Title (from source, before sanitization)
- Start/end datetime (ISO-8601)
- SHA-256 hash of id+startISO+endISO (for change detection)
- `ekEventID` — the EKEvent identifier of the corresponding target calendar event

Top-level fields also include:
- `lastSyncISO` — timestamp of the last successful sync
- `lastBlockTitle` — the block title active at last sync (used to detect renames)

| Condition | Action |
|---|---|
| Event in source, not in snapshot | **Create** in target calendar |
| Event in both, hash changed | **Update** in target calendar |
| Event in snapshot, not in source | **Delete** from target calendar |
| Event in both, hash unchanged | Skip |

> **Important:** `state.json` is only written after a **fully successful sync**.
> If any operation fails, EventKit changes are rolled back and state is not updated.

### Calendar-change invalidation

When the user saves a config with a different `sourceCalendarID` or `targetCalendarID`,
`state.json` is **deleted immediately**. The next sync treats every source event as new
and re-creates all blocks on the new target calendar.

Because those new blocks would be duplicates if the old calendar happened to be the same
physical calendar (unlikely but possible), the duplicate guard below prevents this.

### Duplicate guard

Before creating any new block, the sync engine scans the target calendar for events that
carry the `"honeyDue Calendar Sync"` ownership marker with the **exact same start and end
time**. If one is found, the create is skipped and the existing event's ID is recorded in
state so future runs track it normally.

### Block-title rename sweep

If `config.blockTitle` differs from `state.lastBlockTitle` (i.e. the user renamed the
block between runs), the sync engine runs a **pre-pass** that:
1. Fetches all owned events on the target calendar within the lookahead window.
2. Renames each one to the new title in a committed batch.

This ensures the target calendar is clean before the main diff runs, preventing stale
titles from appearing alongside newly-named blocks.

---

## Configuration (config.json)

Persisted to `~/Library/Application Support/HoneyDueCalSync/config.json`

| Field | Type | Default | Description |
|---|---|---|---|
| `sourceCalendarID` | String | `""` | EKCalendar persistent identifier — source (work) calendar |
| `sourceCalendarName` | String | `""` | Display name of source calendar (UI only) |
| `targetCalendarID` | String | `""` | EKCalendar persistent identifier — target (personal) calendar |
| `targetCalendarName` | String | `""` | Display name of target calendar (UI only) |
| `lookaheadDays` | Int | `60` | Rolling window size in days (1–365) |
| `blockTitle` | String | `"IBM - BLOCK"` | Title written to every target calendar entry |
| `logPath` | String | `""` | Log file path (empty = Application Support default) |
| `syncIntervalMinutes` | Int | `60` | Sync interval in minutes (60–720, hourly steps) |
| `launchAtLogin` | Bool | `true` | Register as macOS Login Item |
| `startMinimized` | Bool | `false` | Hide window on launch, tray only |

---

## All Files Live in One Place

All generated files are in `~/Library/Application Support/HoneyDueCalSync/`:

| File | Description |
|---|---|
| `config.json` | User configuration |
| `state.json` | Last sync snapshot |
| `run.log` | Log output |

No files are scattered elsewhere. No `~/run.log`, no relative paths.

---

## Project File Layout

```
honeydue-cal-sync/
├── design.md                        # This file — start here after any context loss
├── Package.swift                    # Swift Package Manager manifest
├── GOOGLE_SETUP.md                  # (Legacy — no longer needed, kept for reference)
├── Sources/
│   └── HoneyDueCalSync/
│       ├── main.swift               # Entry point — manual NSApplication wiring
│       ├── Models.swift             # Meeting, SyncState, AppConfig, SyncStatus, AppPaths
│       ├── CalendarReader.swift     # Reads events from source calendar via EventKit
│       ├── EventKitSync.swift       # Writes sanitised blocks to target calendar via EventKit
│       ├── DiffEngine.swift         # Compare source events vs state.json snapshot
│       ├── SyncEngine.swift         # Orchestration: read→diff→write→commit→save
│       ├── AppConfig.swift          # ConfigManager: load/save/validate config.json
│       ├── StatusState.swift        # @MainActor observable state (stoplight, counters)
│       ├── TrayController.swift     # NSStatusItem + context menu
│       ├── SettingsView.swift       # SwiftUI settings window
│       ├── AppDelegate.swift        # App entry point, tray, timer, login item
│       ├── Logger.swift             # Append-only log file writer
│       └── Info.plist               # Bundle ID + Calendar/AppleEvents usage strings
├── Tests/
│   └── HoneyDueCalSyncTests/
│       ├── DiffEngineTests.swift    # Diff logic: new/changed/deleted/unchanged/mixed
│       ├── AppConfigTests.swift     # Validation: calendar IDs, lookahead, intervals, title
│       └── ModelsTests.swift        # JSON round-trips, SyncResult, AppPaths
└── assets/
    ├── icon.svg                     # App icon source
    └── banner.svg                   # GUI banner source
```

**Deleted (no longer in project):**
- `OutlookReader.swift` — replaced by `CalendarReader.swift` (EventKit)
- `GoogleCalendarAPI.swift` — replaced by `EventKitSync.swift`
- `Sanitizer.swift` — sanitization is now inline in `EventKitSync.swift`

---

## Swift Dependencies

No third-party dependencies. Everything is macOS SDK:

| Capability | API |
|---|---|
| Read source calendar | `EventKit.EKEventStore` |
| Write target calendar | `EventKit.EKEventStore` |
| Tray icon | `AppKit.NSStatusItem` |
| Settings window | `SwiftUI` |
| Login at startup | `ServiceManagement.SMAppService` |
| JSON persistence | `Foundation.JSONEncoder` / `JSONDecoder` |
| Hashing | `CryptoKit.SHA256` |

Build:
```bash
swift build --configuration release
```

---

## GUI Layout (Current)

```
+----------------------------------------------------------+
|  [banner — bee + HoneyDue branding — navy/gold]          |
+----------------------------------------------------------+
|                                                          |
|  SOURCE  (read from)                                     |
|  Source Calendar    [Calendar — IBM account    ▼] [↺]    |
|                     The work calendar w/ IBM meetings    |
|  Lookahead Days     [60 days ▲▼]                         |
|                                                          |
|  TARGET  (write to)                                      |
|  Target Calendar    [Work — iCloud             ▼] [↺]    |
|                     The personal calendar for blocks     |
|  Block Title        [IBM - BLOCK_____________]           |
|                     Name shown on every entry            |
|                                                          |
|  OPTIONS                                                 |
|  Log File           [________________] [Browse]          |
|  Sync Interval      [Every 1 hour ▼]                     |
|  [x] Start automatically when I log in                   |
|  [ ] Start minimized to tray icon                        |
|                                                          |
|  --------------------------------------------------------|
|  [  Save Config  ]              [  Run Now  ]            |
|                                                          |
|  Last Run:   —                                           |
|  Status:     ● No sync run yet                           |
|  Next Run:   in 60 minutes                               |
|                                                          |
|  --------------------------------------------------------|
|  [  View Log File  ]        [  Hide to Tray  ]           |
+----------------------------------------------------------+
```

---

## Tray Icon

Bee emoji + coloured status dot:

| State | Dot | Meaning |
|---|---|---|
| Never synced | Grey | App running, no sync yet |
| Syncing | Yellow | Sync in progress |
| Last run OK | Green | All good |
| Last run failed | Red | Check GUI for details |

Right-click tray menu shows: last run timestamp, next run countdown, Show Window, Run Now, Quit.

---

## Sync Interval Options

8 choices:

| Label | Minutes |
|---|---|
| Every 15 minutes | 15 |
| Every 30 minutes | 30 |
| Every 1 hour | 60 |
| Every 2 hours | 120 |
| Every 4 hours | 240 |
| Every 6 hours | 360 |
| Every 12 hours | 720 |
| Every 24 hours | 1440 |

---

## Startup Behaviour

- App does **not** auto-sync on startup
- First sync is triggered by: timer expiry OR Run Now button
- If `startMinimized` is true: tray icon appears but settings window stays hidden
- Timer starts counting from app launch

---

## Known Issues / Testing Status

### ✅ Working / Confirmed
- App launches with tray icon + settings window
- Calendar.app calendars load into both Source and Target dropdowns
- Config saves/loads correctly to Application Support
- Log file writes to Application Support (never to `~`)
- Build compiles clean with zero errors
- Create, update (move), delete all working
- Recurring events work (fixed crash with `enumerateEvents`)
- All-day events work
- Multi-day events work (start/end copied verbatim, no clipping)
- Back-to-back meetings work
- 60-day window boundary works (tested with 3 and 5 day windows)
- Block title security confirmed — no details leak
- Run Now disabled while sync is running
- Config reloads correctly on relaunch
- Source/target pickers exclude each other's selection (no same-calendar risk)
- GUI fits without scrolling (660×680 fixed window)
- Both checkboxes on same row with `||` separator (login + minimized)
- `-t` flag enables 1-minute timer option for testing (shows "TESTING MODE" badge)
- Sub-60-minute interval saved during testing is auto-reset to 60 min on next non-test launch
- Timer auto-sync fires correctly (confirmed with `-t` + 1-minute interval)
- Tray context menu: Last run / Next run show in full black, non-selectable
- Hide Window added to tray menu
- Batch mode (`--batch`) confirmed working
- Log rotation: entries older than 10 days purged on every write
- Log size cap: file >10 MB deleted before read (memory safety)
- Lookahead days clamped to 1–100 in UI and validation
- About window: photo, tagline, email — launched from tray menu
- Image bundled via SPM `.process("Resources")`

### 🔲 Needs Testing (deferred)
- "Start at login" — requires signed .app bundle; will test with release build

### 🔲 Known Limitations
- `SMAppService.mainApp.register()` fails in debug builds (needs signed .app bundle)
  — "Login item register failed: Invalid argument" in log is expected during development
- `OutlookReader.swift` is still in the source tree but unused — safe to delete
- Windows support: not applicable (macOS EventKit only)

---

## Decisions Log

| Decision | Choice | Reason |
|---|---|---|
| Language | Swift | Native macOS, proper tray, distributable .app |
| GUI | SwiftUI | Modern, native, perfect for a settings form |
| Tray | NSStatusItem | First-class macOS API |
| Calendar source | EventKit (macOS Calendar.app) | Outlook 16.x AppleScript broken for Exchange accounts |
| Calendar target | EventKit (macOS Calendar.app) | Same store, no extra auth |
| Google Calendar API | **Removed** | EventKit is simpler, no OAuth, no credentials |
| Outlook AppleScript | **Removed** | Returns 0 events in Outlook 16.80+ for Exchange |
| Sanitization | Block title only | Strongest security — zero meeting details leak |
| State persistence | JSON in Application Support | Simple, no DB needed |
| All app files | Application Support only | No scattered files in ~ |
| Auto-sync on startup | **Disabled** | First sync on timer or Run Now only |
| Third-party deps | None | Everything in macOS SDK |

---

## Unit Tests

35 tests across 3 suites covering the pure-logic layers (no EventKit required):

| Suite | Tests | Coverage |
|---|---|---|
| `DiffEngineTests` | 7 | New, unchanged, changed, deleted, ekEventID forwarding, mixed batch, empty |
| `AppConfigTests` | 12 | All validation rules: calendar IDs, lookahead bounds, all 8 sync intervals, block title |
| `ModelsTests` | 16 | JSON round-trips for all model types, SyncResult summaries, AppPaths log URL resolution |

```bash
# Run tests (standalone — no app launch needed)
swift test
```

Tests are also run automatically by `./build.sh` — a failing test aborts the DMG build.

**Not unit-tested** (require live EventKit / device): `SyncEngine`, `CalendarReader`, `EventKitSync`. These are covered by manual testing using the `-t` (1-minute timer) flag.

---

## Build & Run

```bash
# Debug build (fast iteration)
swift build

# Run (debug)
open .build/debug/HoneyDueCalSync

# Check log
cat ~/Library/Application\ Support/HoneyDueCalSync/run.log
```

---

## Release Build — Installable DMG

When asked to "build" the app, always produce a signed, installable `.dmg` with the
version number embedded in the filename (e.g. `HoneyDue-Calendar-Sync-1.0.6.dmg`).

```bash
./build.sh
```

Output files land in `build/`:
- `build/HoneyDueCalSync.app` — signed .app bundle
- `build/HoneyDue-Calendar-Sync-<VERSION>.dmg` — drag-to-install disk image

---

## Version Number — Where to Update

The version string lives in **5 places**. All must be changed together whenever the
version bumps. Missing any one of them causes the displayed version to be wrong.

| File | What to change |
|---|---|
| `Sources/HoneyDueCalSync/Info.plist` | `CFBundleShortVersionString` value |
| `Sources/HoneyDueCalSync/InstructionsView.swift` | Two `Text("… v1.x.x …")` strings (lines with version in them) |
| `README.md` | `**Version 1.x.x**` header + `HoneyDue-Calendar-Sync-1.x.x.dmg` filename |
| `build.sh` | `VERSION="1.x.x"` variable near the top |

> **Tip:** Run `grep -r "1\.0\." --include="*.swift" --include="*.md" --include="*.plist" --include="*.sh" .`
> to confirm all occurrences are updated before building.

---

*Last updated: session 6 — ownership marker (`"honeyDue Calendar Sync"` in notes), duplicate guard, block-title rename sweep, calendar-change state invalidation. Session 7 — version bump checklist + release build instructions added to design.md. Session 8 — sync intervals revised (15 min, 30 min, 1–24 h); 35 unit tests added (DiffEngine, AppConfig, Models); build.sh gates on test pass; version bumped to 1.0.6. Session 9 — fix 15/30 min sync interval clamp bug; version bumped to 1.0.7.*
