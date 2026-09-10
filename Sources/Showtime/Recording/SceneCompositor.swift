import AppKit
import QuartzCore
import SwiftUI
import ShowtimeCore

@MainActor
enum SceneCompositor {
    struct Effects: Sendable {
        let camera: CameraState
        let pointer: PointerState
        let caption: CaptionState?
        let pulses: [ClickPulse]

        @MainActor init(_ state: EffectsState) {
            camera = state.camera; pointer = state.pointer
            caption = state.caption; pulses = state.pulses
        }
    }

    private static var backdropCache: (key: String, image: CGImage)?
    static func color(_ hex: String, alpha: Double = 1) -> NSColor {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x4A8234
        return NSColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
                       blue: Double(value & 255) / 255, alpha: alpha)
    }

    static func render(model: StudioModel, webImage: CGImage, width: Int, height: Int) throws -> CGImage {
        try autoreleasepool {
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ShowtimeError("Could not allocate the film canvas.") }
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: Double(width) / Double(model.canvas.width), y: -Double(height) / Double(model.canvas.height))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            defer { NSGraphicsContext.restoreGraphicsState() }
            drawContent(canvas: model.canvas, camera: model.effects.camera, webImage: webImage,
                        backdrop: try browserBackdrop(model: model, width: width, height: height), context: ctx)
            drawEffects(model: model, context: ctx, time: CACurrentMediaTime())
            guard let image = ctx.makeImage() else { throw ShowtimeError("Could not render the film frame.") }
            return image
        }
    }

    // Only immutable images and geometry cross to the recording worker.
    nonisolated static func drawContent(canvas: CanvasSpec, camera: CameraState, webImage: CGImage,
                                       backdrop: CGImage, context ctx: CGContext) {
        drawImage(backdrop, in: CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height), context: ctx)
        let layout = canvas.layout
        let screen = layout.canvasScreen, page = layout.canvasPage
        ctx.saveGState()
        let outline = layout.screenPath(in: screen)
        ctx.addPath(outline); ctx.clip()
        ctx.saveGState(); ctx.clip(to: page)
        ctx.translateBy(x: page.minX, y: page.minY)
        ctx.translateBy(x: camera.focus.x * (1 - camera.scale), y: camera.focus.y * (1 - camera.scale))
        ctx.scaleBy(x: camera.scale, y: camera.scale)
        drawImage(webImage, in: CGRect(origin: .zero, size: page.size), context: ctx)
        ctx.restoreGState()
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.1))
        ctx.setLineWidth(0.7 * layout.scale); ctx.addPath(outline); ctx.strokePath()
        ctx.restoreGState()
    }

    static func browserBackdrop(model: StudioModel, width: Int, height: Int) throws -> CGImage {
        let c = model.canvas
        let key = "\(width):\(height):\(c.width):\(c.height):\(c.inset):\(c.backdrop):\(c.browserTheme):\(c.frame.rawValue):\(model.displayTitle):\(model.displayURL):\(model.faviconRevision)"
        if let cache = backdropCache, cache.key == key { return cache.image }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ShowtimeError("Could not render the browser backdrop.")
        }
        context.translateBy(x: 0, y: Double(height))
        context.scaleBy(x: Double(width) / Double(c.width), y: -Double(height) / Double(c.height))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }
        let bounds = CGRect(x: 0, y: 0, width: c.width, height: c.height)
        drawBackdrop(context: context, rect: bounds, style: c.backdrop)
        DeviceFrameRenderer.draw(canvas: c, context: context)
        if c.frame.showsBrowserChrome {
            let layout = c.layout
            let pixelScale = layout.scale * max(Double(width) / Double(c.width), Double(height) / Double(c.height))
            context.translateBy(x: layout.origin.x, y: layout.origin.y)
            context.scaleBy(x: layout.scale, y: layout.scale)
            context.addPath(layout.screenPath(in: layout.screen)); context.clip()
            drawImage(try model.chromeImage(scale: pixelScale), in: CGRect(x: layout.screen.minX, y: layout.page.minY - CanvasSpec.chromeHeight,
                width: layout.screen.width, height: CanvasSpec.chromeHeight), context: context)
        }
        guard let image = context.makeImage() else { throw ShowtimeError("Could not cache the browser backdrop.") }
        backdropCache = (key, image)
        return image
    }

    nonisolated static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    static func drawBackdrop(context: CGContext, rect: CGRect, style: String) {
        let colors: [CGColor]
        switch style {
        case "midnight": colors = [color("#142B22").cgColor, color("#21392A").cgColor, color("#17332D").cgColor]
        case "pearl": colors = [color("#F0ECE6").cgColor, color("#F9F6F1").cgColor, color("#E3E8E6").cgColor]
        default: colors = [color("#E3EDDB").cgColor, color("#EEF4E5").cgColor, color("#DCEBDD").cgColor]
        }
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 0.55, 1])!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: rect.width, y: rect.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [NSColor.white.withAlphaComponent(style == "midnight" ? 0.05 : 0.4).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(glow, startCenter: CGPoint(x: rect.width * 0.75, y: 0), startRadius: 0,
                                   endCenter: CGPoint(x: rect.width * 0.75, y: 0), endRadius: rect.width * 0.65, options: [])
    }

    static func drawEffects(model: StudioModel, context: CGContext, time: Double) {
        drawEffects(canvas: model.canvas, effects: Effects(model.effects), context: context, time: time)
    }

    static func drawEffects(canvas c: CanvasSpec, effects: Effects, context: CGContext, time: Double) {
        let layout = c.layout
        let screen = layout.canvasScreen, page = layout.canvasPage
        let camera = effects.camera
        func position(_ p: CGPoint) -> CGPoint {
            let (x, y) = Motion.cameraPoint(x: p.x, y: p.y, focusX: camera.focus.x, focusY: camera.focus.y, scale: camera.scale)
            return CGPoint(x: x, y: y)
        }
        context.saveGState()
        context.addPath(layout.screenPath(in: screen)); context.clip()
        context.translateBy(x: page.minX, y: page.minY)
        context.clip(to: CGRect(origin: .zero, size: page.size))
        for pulse in effects.pulses {
            let progress = min(1, max(0, (time - pulse.started) / 0.75))
            let center = position(pulse.point)
            let radius = 10 + Motion.ease(progress, curve: "smooth") * 27
            context.setStrokeColor(color(effects.pointer.color, alpha: (1 - progress) * 0.65).cgColor)
            context.setFillColor(color(effects.pointer.color, alpha: (1 - progress) * 0.1).cgColor)
            context.setLineWidth(2 * (1 - progress) + 0.5)
            context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.drawPath(using: .fillStroke)
        }
        if effects.pointer.visible { drawPointer(effects.pointer, at: position(effects.pointer.point), context: context) }
        context.restoreGState()
        if let caption = effects.caption { drawCaption(caption, canvas: CGSize(width: c.width, height: c.height), context: context, time: time) }
    }

    static func drawPointer(_ pointer: PointerState, at point: CGPoint, context: CGContext) {
        CursorRenderer.draw(pointer, at: point, context: context)
    }

    static func drawCaption(_ caption: CaptionState, canvas: CGSize, context: CGContext, time: Double) {
        let age = time - caption.started
        guard age >= 0, age < caption.duration, caption.duration > 0 else { return }
        let fadeTime = min(0.4, caption.duration / 2)
        let entrance = Motion.ease(min(1, age / fadeTime), curve: "smooth")
        let exit = Motion.ease(min(1, (caption.duration - age) / fadeTime), curve: "smooth")
        let opacity = min(entrance, exit)
        let minimal = caption.style == "minimal"
        let title = caption.style == "title"
        let foreground = minimal ? color("#202332") : NSColor.white
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineSpacing = 3
        let font = NSFont.systemFont(ofSize: title ? 36 : 25, weight: .semibold)
        let text = NSAttributedString(string: caption.text, attributes: [.font: font, .foregroundColor: foreground, .paragraphStyle: paragraph, .kern: -0.6])
        let maxWidth = min(canvas.width - 180, title ? 850 : 850)
        let textSize = text.boundingRect(with: CGSize(width: maxWidth - 64, height: 250), options: [.usesLineFragmentOrigin, .usesFontLeading]).size
        let subtitle = NSAttributedString(string: caption.subtitle, attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: minimal ? color("#717582") : color("#CBCAD7"), .paragraphStyle: paragraph])
        let subSize = subtitle.boundingRect(with: CGSize(width: maxWidth - 64, height: 100), options: [.usesLineFragmentOrigin]).size
        let eyebrowHeight: Double = caption.eyebrow.isEmpty ? 0 : 23
        let subHeight: Double = caption.subtitle.isEmpty ? 0 : ceil(subSize.height) + 8
        let width = min(maxWidth, max(title ? 540 : 320, max(textSize.width, subSize.width) + 68))
        let height = ceil(textSize.height) + 38 + eyebrowHeight + subHeight
        let y: Double
        switch caption.position { case "center": y = (canvas.height - height) / 2
        case "top": y = 126; default: y = canvas.height - height - 49 }
        let box = CGRect(x: (canvas.width - width) / 2, y: y + (1 - entrance) * 18 + (1 - exit) * 8, width: width, height: height)
        context.saveGState(); context.setAlpha(opacity)
        context.setShadow(offset: CGSize(width: 0, height: 8), blur: 24, color: NSColor.black.withAlphaComponent(0.18).cgColor)
        context.setFillColor((minimal ? NSColor.white.withAlphaComponent(0.97) : color("#1C2B21", alpha: 0.94)).cgColor)
        context.addPath(CGPath(roundedRect: box, cornerWidth: 15, cornerHeight: 15, transform: nil)); context.fillPath()
        context.setShadow(offset: .zero, blur: 0)
        context.setStrokeColor(NSColor.white.withAlphaComponent(minimal ? 0.8 : 0.16).cgColor); context.setLineWidth(0.7)
        context.addPath(CGPath(roundedRect: box.insetBy(dx: 0.4, dy: 0.4), cornerWidth: 15, cornerHeight: 15, transform: nil)); context.strokePath()
        var textY = box.minY + 18
        if !caption.eyebrow.isEmpty {
            let eyebrow = NSAttributedString(string: caption.eyebrow.uppercased(), attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: minimal ? color("#4A8234") : color("#CFE8B5"), .kern: 2.2, .paragraphStyle: paragraph])
            eyebrow.draw(in: CGRect(x: box.minX + 25, y: textY, width: box.width - 50, height: 16))
            textY += eyebrowHeight
        }
        text.draw(in: CGRect(x: box.minX + 28, y: textY, width: box.width - 56, height: ceil(textSize.height) + 3))
        if !caption.subtitle.isEmpty {
            subtitle.draw(in: CGRect(x: box.minX + 28, y: textY + ceil(textSize.height) + 8, width: box.width - 56, height: ceil(subSize.height) + 3))
        }
        context.restoreGState()
    }
}

struct FilmBackdrop: NSViewRepresentable {
    var style: String
    var canvas: CanvasSpec?
    func makeNSView(context: Context) -> BackdropNSView { BackdropNSView() }
    func updateNSView(_ view: BackdropNSView, context: Context) { view.style = style; view.canvas = canvas; view.needsDisplay = true }
}

final class BackdropNSView: NSView {
    var style = "mist"
    var canvas: CanvasSpec?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        if let ctx = NSGraphicsContext.current?.cgContext {
            SceneCompositor.drawBackdrop(context: ctx, rect: bounds, style: style)
            if let canvas { DeviceFrameRenderer.draw(canvas: canvas, context: ctx) }
        }
    }
}

struct EffectsOverlay: NSViewRepresentable {
    let model: StudioModel
    let tick: Date
    func makeNSView(context: Context) -> EffectsNSView { let view = EffectsNSView(); view.model = model; return view }
    func updateNSView(_ view: EffectsNSView, context: Context) { view.needsDisplay = true }
}

final class EffectsNSView: NSView {
    weak var model: StudioModel?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let model, let ctx = NSGraphicsContext.current?.cgContext else { return }
        SceneCompositor.drawEffects(model: model, context: ctx, time: CACurrentMediaTime())
    }
}
