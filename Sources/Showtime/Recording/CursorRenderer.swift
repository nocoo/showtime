import AppKit
import SwiftUI

/// System artwork stays unmodified, including its stroke, shadow, and click hotspot.
@MainActor
enum CursorRenderer {
    struct SystemArtwork {
        let image: CGImage
        let size: CGSize
        let hotSpot: CGPoint
    }
    private static var artwork: [String: SystemArtwork] = [:]

    static func systemArtwork(_ style: String) -> SystemArtwork? {
        if let cached = artwork[style] { return cached }
        let cursor = style == "hand" ? NSCursor.pointingHand : NSCursor.arrow
        let source = cursor.image
        guard source.size.width > 0, source.size.height > 0 else { return nil }
        var proposed = CGRect(origin: .zero, size: CGSize(width: source.size.width * 4, height: source.size.height * 4))
        guard let image = source.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { return nil }
        // NSCursor images include generous transparent padding. Trim only empty pixels
        // so the size control describes the visible artwork, preserving the hotspot.
        let bounds = alphaBounds(image)
        let pixelsPerPoint = CGSize(width: Double(image.width) / source.size.width, height: Double(image.height) / source.size.height)
        let value = SystemArtwork(image: image.cropping(to: bounds) ?? image,
                                  size: CGSize(width: bounds.width / pixelsPerPoint.width, height: bounds.height / pixelsPerPoint.height),
                                  hotSpot: CGPoint(x: cursor.hotSpot.x - bounds.minX / pixelsPerPoint.width,
                                                   y: cursor.hotSpot.y - bounds.minY / pixelsPerPoint.height))
        artwork[style] = value
        return value
    }

    private static func alphaBounds(_ image: CGImage) -> CGRect {
        let bitmap = NSBitmapImageRep(cgImage: image)
        let full = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard bitmap.hasAlpha, bitmap.bitsPerSample == 8, !bitmap.isPlanar, let pixels = bitmap.bitmapData else { return full }
        let alpha = bitmap.bitmapFormat.contains(.alphaFirst) ? 0 : bitmap.samplesPerPixel - 1
        var left = image.width, top = image.height, right = -1, bottom = -1
        for y in 0..<image.height {
            for x in 0..<image.width where pixels[y * bitmap.bytesPerRow + x * bitmap.samplesPerPixel + alpha] > 0 {
                left = min(left, x); top = min(top, y); right = max(right, x); bottom = max(bottom, y)
            }
        }
        return right >= left ? CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1) : full
    }

    static func draw(_ pointer: PointerState, at point: CGPoint, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: point.x, y: point.y)
        let press = pointer.pressed ? 0.9 : 1.0

        if pointer.style == "arrow" || pointer.style == "hand" {
            guard let asset = systemArtwork(pointer.style) else { return }
            let scale = pointer.size / asset.size.height * press
            context.scaleBy(x: scale, y: scale)
            SceneCompositor.drawImage(asset.image, in: CGRect(x: -asset.hotSpot.x, y: -asset.hotSpot.y,
                                                               width: asset.size.width, height: asset.size.height), context: context)
            return
        }

        let scale = pointer.size / 28 * press
        context.scaleBy(x: scale, y: scale)
        let accent = SceneCompositor.color(pointer.color)
        switch pointer.style {
        case "custom":
            if let image = pointer.customImage {
                let ratio = Double(image.height) / Double(image.width)
                // Custom image hotspots are fractions of the full image dimensions.
                SceneCompositor.drawImage(image, in: CGRect(x: -pointer.hotspot.x * 28, y: -pointer.hotspot.y * 28 * ratio,
                                                              width: 28, height: 28 * ratio), context: context)
            }
        case "spotlight":
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
                accent.withAlphaComponent(0.20).cgColor, accent.withAlphaComponent(0.09).cgColor,
                accent.withAlphaComponent(0).cgColor
            ] as CFArray, locations: [0, 0.6, 1])!
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 40, options: [])
            context.setStrokeColor(accent.withAlphaComponent(0.28).cgColor); context.setLineWidth(1)
            context.strokeEllipse(in: CGRect(x: -24, y: -24, width: 48, height: 48))
            drawDot(radius: 4, color: accent, context: context)
        case "dot":
            drawDot(radius: 7, color: accent, context: context)
        default:
            context.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: NSColor.black.withAlphaComponent(0.16).cgColor)
            context.setFillColor(accent.withAlphaComponent(0.06).cgColor)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor); context.setLineWidth(4.5)
            context.addEllipse(in: CGRect(x: -12, y: -12, width: 24, height: 24)); context.drawPath(using: .fillStroke)
            context.setShadow(offset: .zero, blur: 0)
            context.setStrokeColor(accent.cgColor); context.setLineWidth(2)
            context.strokeEllipse(in: CGRect(x: -12, y: -12, width: 24, height: 24))
            context.setFillColor(accent.cgColor)
            context.fillEllipse(in: CGRect(x: -1.75, y: -1.75, width: 3.5, height: 3.5))
        }
    }

    private static func drawDot(radius: Double, color: NSColor, context: CGContext) {
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        context.setFillColor(color.cgColor); context.setStrokeColor(NSColor.white.cgColor); context.setLineWidth(2)
        context.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        context.drawPath(using: .fillStroke)
    }
}

/// Inspector previews and the exported film use exactly the same renderer.
struct CursorPreview: NSViewRepresentable {
    var pointer: PointerState
    func makeNSView(context: Context) -> CursorPreviewNSView { CursorPreviewNSView() }
    func updateNSView(_ view: CursorPreviewNSView, context: Context) { view.pointer = pointer; view.needsDisplay = true }
}

final class CursorPreviewNSView: NSView {
    var pointer = PointerState()
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        var point = CGPoint(x: bounds.midX, y: bounds.midY)
        if ["arrow", "hand"].contains(pointer.style), let asset = CursorRenderer.systemArtwork(pointer.style) {
            let scale = pointer.size / asset.size.height
            point.x += (asset.hotSpot.x - asset.size.width / 2) * scale
            point.y += (asset.hotSpot.y - asset.size.height / 2) * scale
        }
        CursorRenderer.draw(pointer, at: point, context: context)
    }
}
