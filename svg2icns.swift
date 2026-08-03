#!/usr/bin/env swift
// svg2icns.swift — converts SVG → icns using NSImage/Quartz (no WebKit, no deps)
import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: svg2icns.swift <input.svg> <output.icns>\n", stderr); exit(1)
}
let svgPath  = CommandLine.arguments[1]
let icnsPath = CommandLine.arguments[2]

guard let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)),
      let svgStr  = String(data: svgData, encoding: .utf8) else {
    fputs("Cannot read \(svgPath)\n", stderr); exit(1)
}

// Wrap SVG in an HTML data URL — NSImage can load this via its PDF/image pipeline
// We'll rasterise by drawing into a bitmap context at each required size.
let tmpSVG = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hdcs_icon.svg")
try svgData.write(to: tmpSVG)

guard let baseImage = NSImage(contentsOf: tmpSVG) else {
    fputs("NSImage could not load SVG — trying PDF path\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("hdcs_icon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func renderPNG(size: Int) -> Data? {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    baseImage.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
                   from: .zero, operation: .copy, fraction: 1.0)
    img.unlockFocus()
    guard let tiff = img.tiffRepresentation,
          let bmp  = NSBitmapImageRep(data: tiff) else { return nil }
    return bmp.representation(using: .png, properties: [:])
}

// iconset requires these specific filenames
let entries: [(name: String, size: Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

for entry in entries {
    guard let png = renderPNG(size: entry.size) else {
        fputs("Failed to render size \(entry.size)\n", stderr); exit(1)
    }
    try png.write(to: iconsetURL.appendingPathComponent(entry.name))
    print("  rendered \(entry.name)")
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsPath]
try proc.run(); proc.waitUntilExit()

guard proc.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr); exit(1)
}
print("✓ Created \(icnsPath)")
