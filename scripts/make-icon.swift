// Renders the app icon (1024 px PNG) from the Sig-Net wordmark: a white rounded square on the macOS icon grid,
// the logo centred, "Test Suite" under it in the logo's teal. Usage: swift scripts/make-icon.swift <logo.png> <out.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let logo = NSImage(contentsOfFile: args[1]) else { fatalError("usage: make-icon.swift <logo.png> <out.png>") }
let size = 1024.0, inset = 100.0 // Apple's grid: an 824 px body on a 1024 canvas
let teal = NSColor(srgbRed: 0.04, green: 0.37, blue: 0.38, alpha: 1)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let body = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
NSColor.white.setFill()
NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).fill()
NSShadow().set()

let w = body.width - 80, h = w * logo.size.height / logo.size.width
logo.draw(in: NSRect(x: (size - w) / 2, y: size / 2 - h / 2 + 40, width: w, height: h))

let label = NSAttributedString(string: "Test Suite", attributes: [
    .font: NSFont.systemFont(ofSize: 96, weight: .semibold), .foregroundColor: teal,
])
let ls = label.size()
label.draw(at: NSPoint(x: (size - ls.width) / 2, y: size / 2 - h / 2 - ls.height - 10))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
