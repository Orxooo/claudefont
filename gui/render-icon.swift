// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Orxooo
import AppKit
import Foundation

// The selected artwork is retained in the source tree; build every native icon size.
let arguments = CommandLine.arguments
if arguments.count != 2 { fputs("usage: render-icon.swift OUTPUT.iconset\n", stderr); exit(2) }
let destination = URL(fileURLWithPath: arguments[1], isDirectory: true)
let artwork = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("assets/claudefont-icon.png")
guard let source = NSImage(contentsOf: artwork) else { fputs("Cannot read icon artwork\n", stderr); exit(1) }
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for (base, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let pixels = base * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    let filename = "icon_\(base)x\(base)" + (scale == 2 ? "@2x" : "") + ".png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
}
