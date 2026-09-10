import AppKit
import SwiftUI

struct WebSurfaceView: NSViewRepresentable {
    let model: StudioModel

    func makeNSView(context: Context) -> BrowserSurface {
        let view = BrowserSurface(engine: model.browser, effects: model.effects)
        model.browser.surface = view
        return view
    }

    func updateNSView(_ nsView: BrowserSurface, context: Context) {
        // SwiftUI sets the frame when the canvas changes; effects do not relayout the webpage.
    }
}

@MainActor
final class BrowserSurface: NSView {
    let engine: BrowserEngine
    let camera: CameraSurface
    override var isFlipped: Bool { true }

    init(engine: BrowserEngine, effects: EffectsState) {
        self.engine = engine
        self.camera = CameraSurface(engine: engine, effects: effects)
        super.init(frame: engine.webView.bounds)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        addSubview(engine.webView)
        addSubview(camera)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        engine.webView.frame = bounds
        camera.frame = bounds
    }

    func updateCamera(image: CGImage? = nil) {
        if let image { camera.image = image }
        camera.isHidden = camera.effects.camera.scale <= 1.001
        camera.needsDisplay = true
    }
}

@MainActor
final class CameraSurface: NSView {
    weak var engine: BrowserEngine?
    let effects: EffectsState
    var image: CGImage?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    init(engine: BrowserEngine, effects: EffectsState) {
        self.engine = engine; self.effects = effects
        super.init(frame: .zero)
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.clip(to: bounds)
        let c = effects.camera
        ctx.translateBy(x: c.focus.x * (1 - c.scale), y: c.focus.y * (1 - c.scale))
        ctx.scaleBy(x: c.scale, y: c.scale)
        SceneCompositor.drawImage(image, in: bounds, context: ctx)
        ctx.restoreGState()
    }

    private func pagePoint(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil), c = effects.camera
        return CGPoint(x: (p.x - c.focus.x) / c.scale + c.focus.x, y: (p.y - c.focus.y) / c.scale + c.focus.y)
    }
    override func mouseDown(with event: NSEvent) { try? engine?.mouse(.leftMouseDown, at: pagePoint(event)) }
    override func mouseUp(with event: NSEvent) { try? engine?.mouse(.leftMouseUp, at: pagePoint(event)) }
    override func mouseDragged(with event: NSEvent) { try? engine?.mouse(.leftMouseDragged, at: pagePoint(event)) }
    override func mouseMoved(with event: NSEvent) { try? engine?.mouse(.mouseMoved, at: pagePoint(event)) }
    override func scrollWheel(with event: NSEvent) {
        try? engine?.scroll(at: pagePoint(event), deltaX: -event.scrollingDeltaX, deltaY: -event.scrollingDeltaY)
    }
}
