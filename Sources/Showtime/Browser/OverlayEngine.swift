import AppKit
import QuartzCore
import SwiftUI
import WebKit
import ShowtimeCore

/// An independent renderer: it never participates in the website's input or cookie session.
@MainActor
final class OverlayEngine: NSObject, WKNavigationDelegate, WKUIDelegate {
    unowned let model: StudioModel
    let surface = OverlaySurface()
    private var webView: OverlayWebView?
    private var source: URL?
    private var props: [String: JSONValue] = [:]
    private var origin: Double?
    private var duration: Double?
    private var ready = false
    private var loaded = false
    private var active = false
    private var failure: Error?
    private var generation = UUID()
    private var changing = false
    private var drawing = false
    private var lastImage: CGImage?
    private var lastFrame = 0

    init(model: StudioModel) { self.model = model; super.init() }

    var isActive: Bool { active && ready }
    var state: [String: Any] {
        var value: [String: Any] = ["active": isActive, "ready": ready, "frame": lastFrame,
                                    "props": props.mapValues(\.foundation), "clickThrough": true]
        if let source { value["source"] = source.absoluteString }
        if let duration { value["duration"] = duration }
        if let failure { value["error"] = failure.localizedDescription }
        return value
    }

    func reset() {
        generation = UUID()
        active = false; ready = false; loaded = false; failure = nil
        source = nil; props = [:]; origin = nil; duration = nil; lastImage = nil; lastFrame = 0
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
    }

    /// Setup holds frame zero. Every rehearsal/take starts the prepared layer at zero again.
    func startTimeline(at time: Double) { if active { origin = time; lastFrame = 0 } }

    func apply(_ action: Action, preparing: Bool) async throws {
        changing = true
        defer { changing = false }
        while drawing { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(2)) }
        if action.clear == true {
            active = false; lastImage = nil; surface.isHidden = true
            return
        }
        if let url = try action.overlaySourceURL {
            reset()
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            config.mediaTypesRequiringUserActionForPlayback = .all
            config.preferences.javaScriptCanOpenWindowsAutomatically = false
            // Native hit testing alone does not stop autofocus or JS focus() from
            // moving WebKit's internal first responder away from the real page.
            config.userContentController.addUserScript(WKUserScript(
                source: "document.documentElement.inert = true;",
                injectionTime: .atDocumentStart, forMainFrameOnly: false))
            let view = OverlayWebView(frame: surface.bounds, configuration: config)
            view.navigationDelegate = self; view.uiDelegate = self
            view.appearance = NSAppearance(named: .aqua)
            view.underPageBackgroundColor = .clear
            // WebKit's macOS background drawing must also be disabled for alpha snapshots.
            view.setValue(false, forKey: "drawsBackground")
            view.setAccessibilityElement(false)
            view.isInspectable = true
            webView = view; source = url
            surface.isHidden = false
            surface.addSubview(view)
            surface.layoutSubtreeIfNeeded()
            if url.isFileURL { view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
            else { view.load(URLRequest(url: url)) }
            let deadline = CACurrentMediaTime() + (action.timeout ?? 15)
            do {
                while !loaded {
                    try Task.checkCancellation()
                    if let failure { throw failure }
                    guard CACurrentMediaTime() < deadline else { throw ShowtimeError("Overlay page load timed out.") }
                    try await Task.sleep(for: .milliseconds(20))
                }
                while true {
                    let available = try await javaScript("return typeof window.showtimeOverlay === 'function';", timeout: max(0.01, deadline - CACurrentMediaTime()))
                    if available as? Bool == true { break }
                    guard CACurrentMediaTime() < deadline else {
                        throw ShowtimeError("Overlay must define window.showtimeOverlay(context) before it can render.")
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                ready = true
            } catch { fail(error); throw error }
        }
        guard ready else { throw ShowtimeError("Load an overlay source before updating its props.") }
        failure = nil
        if let props = action.props { self.props = props }
        duration = action.duration
        origin = preparing ? nil : CACurrentMediaTime()
        active = true; surface.isHidden = false
        do { lastImage = try await draw(at: origin ?? CACurrentMediaTime(), pixelWidth: model.recordingSettings.width) }
        catch { fail(error); throw error }
    }

    func snapshot(at time: Double, pixelWidth: Int? = nil) async throws -> CGImage? {
        if let failure, active { throw failure }
        guard isActive else { return nil }
        if changing { return lastImage }
        while drawing { try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(2)) }
        guard isActive, !changing else { return lastImage }
        drawing = true
        defer { drawing = false }
        let revision = generation
        do {
            let image = try await draw(at: time, pixelWidth: pixelWidth ?? model.recordingSettings.width)
            guard revision == generation else { return nil }
            lastImage = image
            return image
        } catch {
            if revision != generation { return nil }
            fail(error)
            throw error
        }
    }

    private func draw(at time: Double, pixelWidth: Int) async throws -> CGImage? {
        guard let webView, let window = webView.window else { throw ShowtimeError("The overlay Canvas is not visible.") }
        let age = origin.map { max(0, time - $0) } ?? 0
        if let duration, age >= duration {
            active = false; surface.isHidden = true
            return nil
        }
        let fps = model.recordingSettings.fps
        let frame = Int(floor(age * Double(fps)))
        let context: [String: Any] = ["frame": frame, "fps": fps, "time": Double(frame) / Double(fps),
                                     "width": model.canvas.width, "height": model.canvas.height,
                                     "duration": duration as Any? ?? NSNull(), "props": props.mapValues(\.foundation)]
        _ = try await javaScript("""
            await window.showtimeOverlay(context);
            await document.fonts.ready;
            await Promise.all([...document.images].map(image => image.decode()));
            return true;
            """, arguments: ["context": context])
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        config.snapshotWidth = NSNumber(value: ceil(Double(pixelWidth) / max(1, window.backingScaleFactor)))
        config.afterScreenUpdates = true
        let image: NSImage = try await result { completion in
            webView.takeSnapshot(with: config) { image, error in
                if let image { completion(.success(image)) }
                else { completion(.failure(error ?? ShowtimeError("Overlay returned an empty snapshot."))) }
            }
        }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw ShowtimeError("Overlay returned an empty image.")
        }
        lastFrame = frame
        return cg
    }

    private func javaScript(_ body: String, arguments: [String: Any] = [:], timeout: Double = 2) async throws -> Any {
        guard let webView else { throw ShowtimeError("No overlay page is loaded.") }
        do {
            return try await result(timeout: timeout) { completion in
                webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) { completion($0) }
            }
        } catch {
            if let message = (error as NSError).userInfo["WKJavaScriptExceptionMessage"] as? String {
                throw ShowtimeError("Overlay JavaScript: \(message)")
            }
            throw error
        }
    }

    // Poll only the local callback result, so a hung page cannot strand a job or ignore Stop.
    private func result<Value>(timeout: Double = 2, start: (@escaping (Result<Value, Error>) -> Void) -> Void) async throws -> Value {
        var result: Result<Value, Error>?
        let revision = generation
        start { result = $0 }
        let deadline = CACurrentMediaTime() + timeout
        while result == nil {
            try Task.checkCancellation()
            guard revision == generation else { throw CancellationError() }
            guard CACurrentMediaTime() < deadline else { throw ShowtimeError("Overlay renderer timed out. The frame callback must finish within its time limit.") }
            try await Task.sleep(for: .milliseconds(2))
        }
        return try result!.get()
    }

    private func fail(_ error: Error) {
        failure = error; active = false; lastImage = nil; surface.isHidden = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failure = error }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failure = error }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure = ShowtimeError("The overlay renderer process ended.") }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(["http", "https", "file", "about", "blob", "data"].contains(navigationAction.request.url?.scheme?.lowercased() ?? "") ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) { completionHandler(false) }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) { completionHandler(nil) }
}

final class OverlaySurface: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() { super.layout(); for view in subviews { view.frame = bounds } }
}

private final class OverlayWebView: WKWebView {
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override func becomeFirstResponder() -> Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct AnimationOverlay: NSViewRepresentable {
    let model: StudioModel
    func makeNSView(context: Context) -> OverlaySurface { model.overlay.surface }
    func updateNSView(_ view: OverlaySurface, context: Context) {}
}
