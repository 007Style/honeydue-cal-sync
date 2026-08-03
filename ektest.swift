#!/usr/bin/env swift
import EventKit
import Foundation

let store = EKEventStore()
let sema = DispatchSemaphore(value: 0)

if #available(macOS 14.0, *) {
    Task {
        do {
            try await store.requestFullAccessToEvents()
            print("Access granted")
        } catch {
            print("Access error: \(error)")
        }
        sema.signal()
    }
} else {
    store.requestAccess(to: .event) { granted, error in
        print("Granted: \(granted), error: \(String(describing: error))")
        sema.signal()
    }
}
sema.wait()

let cals = store.calendars(for: .event)
print("Total calendars visible: \(cals.count)")
for cal in cals {
    print("  Calendar: '\(cal.title)' id=\(cal.calendarIdentifier)")
}

let start = Date()
let end = Calendar.current.date(byAdding: .day, value: 30, to: start)!
for cal in cals {
    let pred = store.predicateForEvents(withStart: start, end: end, calendars: [cal])
    let events = store.events(matching: pred)
    let owned = events.filter { $0.notes == "honeyDue Calendar Sync" }
    if !events.isEmpty || !owned.isEmpty {
        print("  '\(cal.title)': \(events.count) total events, \(owned.count) owned")
        for e in events {
            print("    Event: '\(e.title ?? "nil")' notes='\(e.notes ?? "nil")'")
        }
    }
}
