import AppKit
import Combine
import QuartzCore
import SwiftUI
import ShowtimeCore

struct CameraState {
    var scale: Double = 1
    var focus = CGPoint(x: 688, y: 335)
}

struct PointerState {
    var point = CGPoint(x: 1000, y: 530)
    var style = "ring"
    var color = Theme.accentHex
    var size: Double = 28
    var visible = false
    var pressed = false
    var clickEffect = true
    var hotspot = CGPoint(x: 0, y: 0)
    var customImage: CGImage?
    var customImagePath: String?
}

struct CaptionState: Identifiable {
    let id = UUID()
    var text: String
    var subtitle: String
    var eyebrow: String
    var style: String
    var position: String
    var started: Double
    var duration: Double
}

struct ClickPulse: Identifiable {
    let id = UUID()
    var point: CGPoint
    var started: Double
}

@MainActor
final class EffectsState: ObservableObject {
    @Published var camera = CameraState()
    @Published var pointer = PointerState()
    @Published var caption: CaptionState?
    @Published var pulses: [ClickPulse] = []
    var captionTask: Task<Void, Never>?

    func reset() {
        captionTask?.cancel()
        camera = CameraState()
        caption = nil
        pulses = []
        pointer.visible = false
        pointer.pressed = false
    }

    func click(at point: CGPoint) {
        guard pointer.clickEffect else { return }
        let pulse = ClickPulse(point: point, started: CACurrentMediaTime())
        pulses.append(pulse)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            self?.pulses.removeAll { $0.id == pulse.id }
        }
    }

    func showCaption(_ action: Action) {
        captionTask?.cancel()
        guard let text = action.text, !text.isEmpty else { caption = nil; return }
        let value = CaptionState(text: text, subtitle: action.subtitle ?? "", eyebrow: action.eyebrow ?? "",
                                 style: action.style ?? "glass", position: action.position ?? "bottom",
                                 started: CACurrentMediaTime(), duration: action.duration ?? 3)
        caption = value
        captionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(value.duration))
            guard !Task.isCancelled, self?.caption?.id == value.id else { return }
            self?.caption = nil
        }
    }
}

@MainActor
final class StudioModel: ObservableObject {
    @Published var canvas = CanvasSpec()
    @Published var actualTitle = "A new scene"
    @Published var actualURL = ""
    @Published var titleOverride = ""
    @Published var urlOverride = ""
    @Published var isLoading = false
    @Published var loadingProgress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var addressEditing = false
    @Published var showInspector = true
    @Published var showConnection = false
    @Published var currentScript: FilmScript?
    @Published var scriptName = "Orbit · A little more momentum"
    @Published var currentStep = -1
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var isPreparing = false
    @Published var isFinishing = false
    @Published var elapsed: Double = 0
    @Published var agentPort: UInt16 = 19840
    @Published var agentReady = false
    @Published var statusText = "Setting the stage"
    @Published var errorMessage: String?
    @Published var lastExportURL: URL?
    @Published var completedTakes = 0
    @Published var selectedInspector = "Canvas"

    let effects = EffectsState()
    let browser = BrowserEngine()
    lazy var recorder = MovieRecorder(model: self)
    lazy var director = Director(model: self)
    lazy var server = AutomationServer(model: self)
    var previewTask: Task<Void, Never>?
    var eventMonitor: Any?
    var started = false
    weak var window: NSWindow?
    weak var stageView: NSView?
    private var chromeCacheKey = ""
    private var chromeCache: CGImage?

    var displayTitle: String { titleOverride.isEmpty ? actualTitle : titleOverride }
    var displayURL: String { urlOverride.isEmpty ? actualURL : urlOverride }
    var isBusy: Bool { isPlaying || isRecording || isFinishing || isPreparing }
    var pageSize: CGSize { CGSize(width: canvas.pageWidth, height: canvas.pageHeight) }
    var demoURL: URL { URL(string: "http://127.0.0.1:\(agentPort)/demo/")! }
    var exportFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Showtime", isDirectory: true)
    }
    var connectionFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Showtime/connection.json")
    }

    init() {
        browser.owner = self
        loadBundledScript()
    }

    func start() {
        guard !started else { return }
        started = true
        if let p = ProcessInfo.processInfo.environment["SHOWTIME_PORT"], let port = UInt16(p), port > 0 { agentPort = port }
        do { try server.start(port: agentPort) }
        catch { report(error) }
        previewTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let tick = CACurrentMediaTime()
                if self.isRecording || self.effects.camera.scale > 1.001 {
                    do {
                        let snapshot = try await self.browser.snapshot()
                        self.browser.surface?.updateCamera(image: snapshot)
                        if self.isRecording { try await self.recorder.consume(webImage: snapshot, at: CACurrentMediaTime()) }
                    } catch {
                        if self.isRecording { await self.recorder.fail(error) }
                    }
                }
                if self.isRecording, self.recorder.elapsed - self.elapsed >= 0.15 { self.elapsed = self.recorder.elapsed }
                let frameInterval = 1.0 / Double(self.isRecording ? self.recorder.spec.fps : 30)
                try? await Task.sleep(for: .seconds(max(0.003, frameInterval - (CACurrentMediaTime() - tick))))
            }
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            guard let self, self.isRecording, !self.isPlaying, event.window == self.browser.webView.window else { return event }
            let screenPoint = self.browser.cssPoint(fromWindow: event.locationInWindow)
            if event.type == .leftMouseUp { self.effects.pointer.pressed = false }
            guard CGRect(origin: .zero, size: self.pageSize).contains(screenPoint) else { return event }
            let camera = self.effects.camera
            let point = CGPoint(x: (screenPoint.x - camera.focus.x) / camera.scale + camera.focus.x,
                                y: (screenPoint.y - camera.focus.y) / camera.scale + camera.focus.y)
            self.effects.pointer.point = point
            self.effects.pointer.visible = true
            if event.type == .leftMouseDown { self.effects.pointer.pressed = true }
            if event.type == .leftMouseDown { self.effects.click(at: point) }
            return event
        }
    }

    func serverBecameReady(port: UInt16) {
        agentPort = port
        agentReady = true
        statusText = "Your next great demo starts here"
        Task { @MainActor in
            do { try await browser.open(demoURL.absoluteString) }
            catch { report(error) }
        }
    }

    func loadBundledScript() {
        guard let url = AppResources.bundle.url(forResource: "orbit-launch", withExtension: "json", subdirectory: "Scripts"),
              let data = try? Data(contentsOf: url), let script = try? JSONDecoder().decode(FilmScript.self, from: data) else { return }
        currentScript = script
        scriptName = script.name
    }

    func importScript() {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.message = "Choose a Showtime film script"
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let script = try JSONDecoder().decode(FilmScript.self, from: Data(contentsOf: url))
            try script.validate(defaultCanvas: canvas)
            currentScript = script
            scriptName = script.name
            currentStep = -1
            statusText = "Script loaded · \(script.steps.count) cues"
            errorMessage = nil
        } catch { report(error) }
    }

    func playDemo(record: Bool) {
        guard !isBusy, var script = currentScript else { return }
        if record {
            if script.recording == nil { script.recording = RecordingSpec() }
        } else { script.recording = nil }
        do { _ = try director.run(script) }
        catch { report(error) }
    }

    func saveCursorPreset() {
        guard !isPlaying, let index = currentScript?.steps.firstIndex(where: { $0.action == .cursor }) else { return }
        let pointer = effects.pointer
        currentScript?.steps[index].style = pointer.style
        currentScript?.steps[index].size = pointer.size
        currentScript?.steps[index].color = pointer.color
        currentScript?.steps[index].clickEffect = pointer.clickEffect
        currentScript?.steps[index].hotspotX = pointer.hotspot.x
        currentScript?.steps[index].hotspotY = pointer.hotspot.y
        currentScript?.steps[index].image = pointer.style == "custom" ? pointer.customImagePath : nil
    }

    func toggleRecording() {
        if isPlaying { director.cancel(); return }
        Task { @MainActor in
            do {
                if isRecording { _ = try await recorder.stop() }
                else { try await recorder.start(RecordingSpec()) }
            } catch { report(error) }
        }
    }

    func navigate(_ url: String) {
        guard !isPlaying, !isFinishing else { return }
        Task { @MainActor in
            do { try await browser.open(url) }
            catch { report(error) }
        }
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
        statusText = "Needs attention"
        FileHandle.standardError.write(Data("Showtime: \(error.localizedDescription)\n".utf8))
    }

    func revealExport() {
        if let lastExportURL { NSWorkspace.shared.activateFileViewerSelecting([lastExportURL]) }
        else {
            try? FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(exportFolder)
        }
    }

    func chromeImage() throws -> CGImage {
        let key = "\(displayTitle)|\(displayURL)|\(canvas.pageWidth)|\(canGoBack)|\(canGoForward)"
        if key == chromeCacheKey, let chromeCache { return chromeCache }
        let renderer = ImageRenderer(content: BrowserChromeView(model: self, exporting: true)
            .frame(width: canvas.pageWidth, height: CanvasSpec.chromeHeight)
            .environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw ShowtimeError("Could not render the browser chrome.") }
        chromeCacheKey = key
        chromeCache = image
        return image
    }

    func screenshot(to path: String) async throws -> URL {
        let image = try await browser.snapshot()
        let frame = try SceneCompositor.render(model: self, webImage: image, width: 1920, height: Int(1920 * Double(canvas.height) / Double(canvas.width)))
        let url = try OutputFiles.newURL(path: path, defaultFolder: exportFolder, ext: "png")
        let data = NSBitmapImageRep(cgImage: frame).representation(using: .png, properties: [:])
        guard let data else { throw ShowtimeError("PNG encoding failed.") }
        try OutputFiles.writeNew(data, to: url)
        return url
    }

    func studioScreenshot(to path: String, nativeOnly: Bool = false) async throws -> URL {
        guard let content = window?.contentView, let stageView, stageView.bounds.width > 0 else { throw ShowtimeError("The studio window is not ready.") }
        let webImage = try await browser.snapshot()
        content.layoutSubtreeIfNeeded()
        guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw ShowtimeError("Could not capture the native studio controls.") }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        if nativeOnly, let data = bitmap.representation(using: .png, properties: [:]) {
            let url = try OutputFiles.newURL(path: path, defaultFolder: exportFolder, ext: "png")
            try OutputFiles.writeNew(data, to: url)
            return url
        }
        guard let nativeImage = bitmap.cgImage,
              let context = CGContext(data: nil, width: nativeImage.width, height: nativeImage.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ShowtimeError("Could not compose the studio screenshot.")
        }
        context.translateBy(x: 0, y: Double(nativeImage.height))
        context.scaleBy(x: Double(nativeImage.width) / content.bounds.width, y: -Double(nativeImage.height) / content.bounds.height)
        SceneCompositor.drawImage(nativeImage, in: content.bounds, context: context)
        let frame = try SceneCompositor.render(model: self, webImage: webImage, width: 1920, height: Int(1920 * Double(canvas.height) / Double(canvas.width)))
        context.saveGState()
        let stageFrame = stageView.convert(stageView.bounds, to: content)
        let captureFrame = content.isFlipped ? stageFrame : CGRect(x: stageFrame.minX, y: content.bounds.height - stageFrame.maxY,
                                                                  width: stageFrame.width, height: stageFrame.height)
        context.addPath(CGPath(roundedRect: captureFrame, cornerWidth: 10, cornerHeight: 10, transform: nil)); context.clip()
        SceneCompositor.drawImage(frame, in: captureFrame, context: context)
        context.restoreGState()
        guard let image = context.makeImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ShowtimeError("Could not encode the studio screenshot.")
        }
        let url = try OutputFiles.newURL(path: path, defaultFolder: exportFolder, ext: "png")
        try OutputFiles.writeNew(data, to: url)
        return url
    }

    func shutdown() async {
        director.cancel()
        await director.waitUntilStopped()
        while isPreparing || isFinishing { try? await Task.sleep(for: .milliseconds(20)) }
        if isRecording { _ = try? await recorder.stop() }
        stopServices()
    }

    func stopServices() {
        previewTask?.cancel()
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
        server.stop()
    }
}

enum OutputFiles {
    static func writeNew(_ data: Data, to url: URL) throws {
        // Foundation forbids combining .atomic with .withoutOverwriting.
        // Stage beside the destination, then move without replacing an existing file.
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".showtime-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        try FileManager.default.moveItem(at: temporary, to: url)
    }

    static func newURL(path: String?, defaultFolder: URL, ext: String) throws -> URL {
        let url: URL
        if let path, !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/") else { throw ShowtimeError("Output paths must be absolute (or start with ~/).") }
            url = URL(fileURLWithPath: expanded).standardizedFileURL
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            url = defaultFolder.appendingPathComponent("Showtime_\(formatter.string(from: Date()))_\(UUID().uuidString.prefix(4)).\(ext)")
        }
        guard url.pathExtension.lowercased() == ext else { throw ShowtimeError("Expected a .\(ext) output path.") }
        guard !FileManager.default.fileExists(atPath: url.path) else { throw ShowtimeError("Output already exists: \(url.path). Choose a new filename.") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return url
    }
}
