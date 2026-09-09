import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let tile = CGRect(x: 78, y: 78, width: 868, height: 868)
let outline = CGPath(roundedRect: tile, cornerWidth: 196, cornerHeight: 196, transform: nil)
ctx.setShadow(offset: CGSize(width: 0, height: -13), blur: 23, color: NSColor.black.withAlphaComponent(0.23).cgColor)
ctx.setFillColor(NSColor(calibratedRed: 0.12, green: 0.19, blue: 0.13, alpha: 1).cgColor)
ctx.addPath(outline); ctx.fillPath(); ctx.setShadow(offset: .zero, blur: 0)
ctx.saveGState(); ctx.addPath(outline); ctx.clip()
let gradient = CGGradient(colorsSpace: space, colors: [NSColor(calibratedRed: 0.10, green: 0.17, blue: 0.12, alpha: 1).cgColor, NSColor(calibratedRed: 0.27, green: 0.39, blue: 0.22, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 160), end: CGPoint(x: 850, y: 1024), options: [])
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.04).cgColor); ctx.setLineWidth(1.5)
for y in stride(from: 132, to: 946, by: 28) { ctx.move(to: CGPoint(x: 78, y: y)); ctx.addLine(to: CGPoint(x: 946, y: y)); ctx.strokePath() }
ctx.restoreGState()
let frame = CGRect(x: 248, y: 295, width: 528, height: 428)
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.16).cgColor)
ctx.setFillColor(NSColor(calibratedRed: 207 / 255, green: 232 / 255, blue: 181 / 255, alpha: 1).cgColor)
ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 57, cornerHeight: 57, transform: nil)); ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0)
ctx.setStrokeColor(NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.16, alpha: 0.16).cgColor); ctx.setLineWidth(3)
ctx.move(to: CGPoint(x: 248, y: 648)); ctx.addLine(to: CGPoint(x: 776, y: 648)); ctx.strokePath()
ctx.setFillColor(NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.16, alpha: 0.16).cgColor)
ctx.addPath(CGPath(roundedRect: CGRect(x: 289, y: 671, width: 270, height: 22), cornerWidth: 11, cornerHeight: 11, transform: nil)); ctx.fillPath()
let play = CGMutablePath(); play.move(to: CGPoint(x: 455, y: 402)); play.addLine(to: CGPoint(x: 455, y: 572)); play.addQuadCurve(to: CGPoint(x: 475, y: 583), control: CGPoint(x: 455, y: 594)); play.addLine(to: CGPoint(x: 613, y: 503)); play.addQuadCurve(to: CGPoint(x: 613, y: 479), control: CGPoint(x: 634, y: 491)); play.addLine(to: CGPoint(x: 475, y: 391)); play.addQuadCurve(to: CGPoint(x: 455, y: 402), control: CGPoint(x: 455, y: 379)); play.closeSubpath()
ctx.setFillColor(NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.16, alpha: 1).cgColor); ctx.addPath(play); ctx.fillPath()
let image = ctx.makeImage()!
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size * scale
        let target = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        target.interpolationQuality = .high
        target.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let bitmap = NSBitmapImageRep(cgImage: target.makeImage()!)
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(filename))
    }
}
