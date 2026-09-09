import AppKit

let path = CommandLine.arguments.dropFirst().first ?? "examples/cursors/diamond.png"
let size = 144
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let shadow = NSShadow(); shadow.shadowOffset = NSSize(width: 0, height: -3); shadow.shadowBlurRadius = 9
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18); shadow.set()
let diamond = NSBezierPath()
diamond.move(to: NSPoint(x: 72, y: 126)); diamond.line(to: NSPoint(x: 122, y: 72))
diamond.line(to: NSPoint(x: 72, y: 18)); diamond.line(to: NSPoint(x: 22, y: 72)); diamond.close()
diamond.lineJoinStyle = .round; diamond.lineWidth = 6
NSColor(srgbRed: 74 / 255, green: 130 / 255, blue: 52 / 255, alpha: 1).setFill(); diamond.fill()
NSColor.white.setStroke(); diamond.stroke()
let center = NSBezierPath(ovalIn: NSRect(x: 66, y: 66, width: 12, height: 12))
NSColor.white.setFill(); center.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
