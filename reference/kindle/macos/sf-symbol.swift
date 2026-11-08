// Draws an SF Symbol (macOS's system icons) as a black PNG on a transparent
// background, for buttons with "icon": "symbol:camera.fill". The server
// compiles it into cache/ the first time a button asks for a symbol.
// Usage: sf-symbol <symbol.name> <out.png> [side=256]
// Names: Apple's SF Symbols app, or https://developer.apple.com/sf-symbols/
import AppKit

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
if args.count < 3 { fail("usage: sf-symbol <symbol> <out.png> [side]", 2) }
let name = args[1], out = args[2]
let side = CGFloat(Double(args.count > 3 ? args[3] : "256") ?? 256)
guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
    fail("there is no symbol called '\(name)'", 1)
}
let config = NSImage.SymbolConfiguration(pointSize: side * 0.6, weight: .semibold, scale: .large)
let symbol = base.withSymbolConfiguration(config) ?? base
let size = symbol.size
let scale = min(side / size.width, side / size.height)
let w = size.width * scale, h = size.height * scale
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    fail("can't create the bitmap", 1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
symbol.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h),
            from: .zero, operation: .sourceOver, fraction: 1)
// Symbols are templates: paint them black and keep their transparency.
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill(using: .sourceIn)
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fail("can't make the PNG", 1) }
do { try png.write(to: URL(fileURLWithPath: out)) } catch { fail("can't write \(out): \(error)", 1) }
