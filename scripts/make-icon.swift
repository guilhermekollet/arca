// Generates Resources/AppIcon.icns: a solid off-white key pointing down on a dark tile.
// Usage: swift scripts/make-icon.swift
import AppKit

let ink = NSColor(srgbRed: 0x17 / 255, green: 0x17 / 255, blue: 0x17 / 255, alpha: 1)
let paper = NSColor(srgbRed: 0xFA / 255, green: 0xFA / 255, blue: 0xFA / 255, alpha: 1)

// The key on a 180-point square, y growing downwards: the same numbers as KeyGlyph in
// Sources/Keys/Theme.swift, which draws it in the app.
let bow = CGRect(x: 58, y: 24, width: 64, height: 64)
let shaft = CGRect(x: 78, y: 70, width: 24, height: 92)
let teeth = [CGRect(x: 96, y: 118, width: 20, height: 13), CGRect(x: 96, y: 137, width: 15, height: 13)]
let hole = CGRect(x: 82, y: 35, width: 16, height: 16)

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = CGFloat(pixels)
    // Standard macOS icon proportions: an 824 square on a 1024 canvas.
    let tile = NSRect(x: size * 0.0977, y: size * 0.0977, width: size * 0.8046, height: size * 0.8046)
    ink.setFill()
    NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237).fill()

    // From the 180-point square onto the tile, turning y the right way up.
    let scale = tile.width / 180
    func place(_ part: CGRect) -> NSRect {
        NSRect(x: tile.minX + part.minX * scale, y: tile.maxY - part.maxY * scale, width: part.width * scale, height: part.height * scale)
    }
    paper.setFill()
    NSBezierPath(ovalIn: place(bow)).fill()
    NSBezierPath(roundedRect: place(shaft), xRadius: 12 * scale, yRadius: 12 * scale).fill()
    for tooth in teeth {
        NSBezierPath(roundedRect: place(tooth), xRadius: 4 * scale, yRadius: 4 * scale).fill()
    }
    ink.setFill()
    NSBezierPath(ovalIn: place(hole)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(1024).write(to: URL(fileURLWithPath: "Resources/icon-1024.png"))

// iconutil turns the iconset into the .icns the app bundle uses.
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try FileManager.default.removeItem(at: iconset)
