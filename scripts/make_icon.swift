import AppKit
import ImageIO

// Generate native consumers from the approved masters. The root PNGs remain
// byte-for-byte originals; the macOS inset belongs only to the app icon.
struct IconError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func readImage(_ relativePath: String) throws -> CGImage {
    let url = root.appendingPathComponent(relativePath)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == 2048, image.height == 2048 else {
        throw IconError(message: "Expected a 2048 × 2048 master at \(url.path).")
    }
    return image
}

func context(size: Int) throws -> CGContext {
    guard let result = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw IconError(message: "Could not allocate the \(size)-pixel icon canvas.")
    }
    result.interpolationQuality = .high
    return result
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw IconError(message: "Could not encode \(url.lastPathComponent).")
    }
    // Keep resource timestamps stable when rebuilding the same artwork.
    if (try? Data(contentsOf: url)) == data { return }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

func resized(_ image: CGImage, to size: Int) throws -> CGImage {
    let canvas = try context(size: size)
    canvas.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let result = canvas.makeImage() else { throw IconError(message: "Could not resize the icon.") }
    return result
}

func generate(in folder: URL) throws {
    let square = try readImage("assets/app-icon-master.png")
    let foreground = try readImage("logo.png")
    let canvas = try context(size: 1024)

    // The macOS tile occupies 824 of 1024 pixels, with transparent outer space
    // for the Dock. Fit the entire square master inside it before rounding.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let outline = CGPath(roundedRect: tile, cornerWidth: 185.4, cornerHeight: 185.4, transform: nil)
    canvas.setShadow(offset: CGSize(width: 0, height: -12), blur: 20,
                     color: NSColor.black.withAlphaComponent(0.18).cgColor)
    canvas.setFillColor(NSColor.white.cgColor)
    canvas.addPath(outline)
    canvas.fillPath()
    canvas.setShadow(offset: .zero, blur: 0)
    canvas.saveGState()
    canvas.addPath(outline)
    canvas.clip()
    canvas.draw(square, in: tile)
    canvas.restoreGState()
    guard let icon = canvas.makeImage() else { throw IconError(message: "Could not render the macOS icon.") }

    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
            try writePNG(resized(icon, to: size * scale), to: folder.appendingPathComponent(filename))
        }
    }
    try writePNG(resized(foreground, to: 256),
                 to: root.appendingPathComponent("Sources/Showtime/Resources/Brand/ShowtimeMark.png"))
    print("Generated 10 macOS icon representations and the transparent toolbar mark.")
}

do {
    guard CommandLine.arguments.count == 2 else {
        throw IconError(message: "Usage: swift scripts/make_icon.swift <output.iconset>")
    }
    try generate(in: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
