import AppKit
import QuartzCore
import SwiftUI
import ShowtimeCore

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
        if engine.webView.frame != bounds { engine.webView.frame = bounds }
        if camera.frame != bounds { camera.frame = bounds }
        camera.update()
    }

    func updateCamera(image: CGImage? = nil) {
        camera.update(image: image)
    }
}

@MainActor
final class CameraSurface: NSView {
    weak var engine: BrowserEngine?
    let effects: EffectsState
    private let imageLayer = CALayer()
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }

    init(engine: BrowserEngine, effects: EffectsState) {
        self.engine = engine; self.effects = effects
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.isGeometryFlipped = true
        layer?.backgroundColor = NSColor.white.cgColor
        imageLayer.anchorPoint = .zero
        imageLayer.contentsGravity = .resize
        imageLayer.minificationFilter = .trilinear
        imageLayer.magnificationFilter = .linear
        layer?.addSublayer(imageLayer)
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(image: CGImage? = nil) {
        // Animate the layer transform instead of redrawing a 4K bitmap on every tick.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let image { imageLayer.contents = image }
        let c = effects.camera
        imageLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        imageLayer.position = .zero
        imageLayer.setAffineTransform(c.transform)
        isHidden = c.isIdentity
        CATransaction.commit()
    }

    private func pagePoint(_ event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil).applying(effects.camera.transform.inverted())
    }
    override func mouseDown(with event: NSEvent) { try? engine?.mouse(.leftMouseDown, at: pagePoint(event)) }
    override func mouseUp(with event: NSEvent) { try? engine?.mouse(.leftMouseUp, at: pagePoint(event)) }
    override func mouseDragged(with event: NSEvent) { try? engine?.mouse(.leftMouseDragged, at: pagePoint(event)) }
    override func mouseMoved(with event: NSEvent) { try? engine?.mouse(.mouseMoved, at: pagePoint(event)) }
    override func scrollWheel(with event: NSEvent) {
        try? engine?.scroll(at: pagePoint(event), deltaX: -event.scrollingDeltaX, deltaY: -event.scrollingDeltaY)
    }
}
