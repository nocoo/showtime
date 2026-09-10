import AppKit
import Combine
import QuartzCore
import SwiftUI
import ShowtimeCore

struct CameraState: Sendable {
    var scale: Double = 1
    var focus = CGPoint(x: CanvasSpec().pageWidth / 2, y: CanvasSpec().pageHeight / 2)
}

struct PointerState: Sendable {
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

struct CaptionState: Identifiable, Sendable {
    let id = UUID()
    var text: String
    var subtitle: String
    var eyebrow: String
    var style: String
    var position: String
    var started: Double
    var duration: Double
}

struct ClickPulse: Identifiable, Sendable {
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

    func reset(pageSize: CGSize) {
        captionTask?.cancel()
        camera = CameraState(scale: 1, focus: CGPoint(x: pageSize.width / 2, y: pageSize.height / 2))
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
    @Published var recordingSettings = RecordingSpec()
    @Published var actualTitle = "A new scene"
    @Published var actualURL = ""
    @Published var favicon: NSImage? {
        didSet { faviconRevision += 1 }
    }
    private(set) var faviconRevision = 0
    @Published var titleOverride = ""
    @Published var urlOverride = ""
    @Published var isLoading = false
    @Published var loadingProgress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var addressEditing = false
    @Published var showInspector = true
    @Published var mode: StudioMode = .studio
    @Published var appearance = StudioAppearance(rawValue: UserDefaults.standard.string(forKey: "studioAppearance") ?? "light") ?? .light {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "studioAppearance") }
    }
    @Published var currentScript: FilmScript?
    @Published var scriptName = "Current webpage"
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
    let toasts = ToastCenter()
    let activity = DirectorActivity()
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
    var theaterMode: Bool {
        get { mode == .theater }
        set { mode = newValue ? .theater : .studio }
    }
    var studioState: [String: Any] {
        ["mode": mode.rawValue, "theme": appearance.rawValue, "inspector": selectedInspector,
         "showInspector": showInspector, "theater": theaterMode]
    }
    var captureState: [String: Any] {
        ["canvas": ["width": canvas.width, "height": canvas.height, "inset": canvas.inset, "backdrop": canvas.backdrop,
                    "browserTheme": canvas.browserTheme, "frame": canvas.frame.rawValue, "contentWidth": canvas.contentWidth as Any? ?? NSNull()],
         "video": ["width": recordingSettings.width, "height": recordingSettings.height, "fps": recordingSettings.fps]]
    }
    var pageSize: CGSize { CGSize(width: canvas.pageWidth, height: canvas.pageHeight) }
    func snapshotPixelWidth(for video: RecordingSpec? = nil) -> Double {
        let video = video ?? recordingSettings
        let density = max(1, Double(video.width) / Double(canvas.width), Double(video.height) / Double(canvas.height))
        return ceil(canvas.pageWidth * density * max(1, effects.camera.scale))
    }
    var demoURL: URL { URL(string: "http://localhost:\(agentPort)/demo/")! }
    var exportFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Showtime", isDirectory: true)
    }
    var connectionFile: URL {
        if let path = ProcessInfo.processInfo.environment["SHOWTIME_CONNECTION"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Showtime/connection.json")
    }

    init() {
        browser.owner = self
        UserDefaults.standard.removeObject(forKey: "lastWebsite")
        if let data = UserDefaults.standard.data(forKey: "captureSettings"),
           let saved = try? JSONDecoder().decode(CaptureSettings.self, from: data),
           (try? saved.canvas.validate()) != nil, (try? saved.video.validate(canvas: saved.canvas)) != nil {
            canvas = saved.canvas
            recordingSettings = saved.video
            recordingSettings.output = nil
        }
        effects.camera = CameraState(scale: 1, focus: CGPoint(x: canvas.pageWidth / 2, y: canvas.pageHeight / 2))
    }

    func start() {
        guard !started else { return }
        started = true
        if let p = ProcessInfo.processInfo.environment["SHOWTIME_PORT"], let port = UInt16(p), port > 0 { agentPort = port }
        do { try server.start(port: agentPort) }
        catch { report(error) }
        previewTask = Task { @MainActor [weak self] in
            typealias Capture = (image: CGImage, canvas: CanvasSpec, effects: SceneCompositor.Effects, time: Double)
            var pending: Task<Capture, Error>?
            defer { pending?.cancel() }
            while !Task.isCancelled {
                guard let self else { return }
                func capture() -> Task<Capture, Error> {
                    Task { @MainActor in
                        let canvas = self.canvas
                        let image = try await self.browser.snapshot()
                        return (image, canvas, SceneCompositor.Effects(self.effects), CACurrentMediaTime())
                    }
                }
                let tick = CACurrentMediaTime()
                if self.isRecording || self.effects.camera.scale > 1.001 {
                    do {
                        let snapshot = try await (pending ?? capture()).value
                        pending = nil
                        guard !Task.isCancelled else { break }
                        guard snapshot.canvas == self.canvas else { continue }
                        // At most one capture overlaps the previous frame's background
                        // composition. Never queue a backlog of stale webpage images.
                        if self.isRecording { pending = capture() }
                        self.browser.surface?.updateCamera(image: snapshot.image)
                        if self.isRecording {
                            try await self.recorder.consume(webImage: snapshot.image, at: snapshot.time, effects: snapshot.effects)
                        }
                    } catch {
                        pending?.cancel(); pending = nil
                        if self.isRecording { await self.recorder.fail(error) }
                    }
                } else {
                    pending?.cancel(); pending = nil
                }
                if self.isRecording, self.recorder.elapsed - self.elapsed >= 0.15 { self.elapsed = self.recorder.elapsed }
                let frameInterval = 1.0 / Double(self.isRecording ? self.recorder.spec.fps : 30)
                try? await Task.sleep(for: .seconds(max(0.001, frameInterval - (CACurrentMediaTime() - tick))))
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
            do { try await browser.open("showtime://demo") }
            catch { report(error) }
        }
    }

    func loadBundledScript() {
        guard !isBusy else { return }
        guard let url = AppResources.bundle.url(forResource: "orbit-launch", withExtension: "json", subdirectory: "Scripts"),
              let data = try? Data(contentsOf: url), let script = try? JSONDecoder().decode(FilmScript.self, from: data) else { return }
        do { try stageScript(script) }
        catch { report(error) }
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
            try stageScript(script)
            statusText = "Script loaded · \(script.steps.count) cues"
            errorMessage = nil
        } catch { report(error) }
    }

    func playStoryboard(record: Bool) {
        guard !isBusy, var script = currentScript else { return }
        script.canvas = canvas
        script.recording = record ? recordingSettings : nil
        do { _ = try director.run(script) }
        catch { report(error) }
    }

    func clearStoryboard() {
        guard !isBusy else { return }
        currentScript = nil
        currentStep = -1
        scriptName = "Current webpage"
    }

    func stageScript(_ script: FilmScript) throws {
        try script.validate(defaultCanvas: canvas)
        let nextCanvas = script.canvas ?? canvas
        var nextVideo = try script.recording ?? recordingSettings.fitted(to: nextCanvas)
        try nextVideo.validate(canvas: nextCanvas)
        nextVideo.output = nil
        updateCanvas(nextCanvas)
        recordingSettings = nextVideo
        currentScript = script
        scriptName = script.name
        currentStep = -1
        persistCaptureSettings()
    }

    func applyCapture(canvas nextCanvas: CanvasSpec? = nil, video nextVideo: RecordingSpec? = nil) throws {
        guard !isBusy else { throw ShowtimeError("The director is busy. Finish the take before changing capture settings.") }
        let nextCanvas = nextCanvas ?? canvas
        try nextCanvas.validate()
        var nextVideo = try nextVideo ?? recordingSettings.fitted(to: nextCanvas)
        try nextVideo.validate(canvas: nextCanvas)
        nextVideo.output = nil
        updateCanvas(nextCanvas)
        recordingSettings = nextVideo
        currentScript?.canvas = nextCanvas
        if var recording = currentScript?.recording {
            recording.width = nextVideo.width; recording.height = nextVideo.height; recording.fps = nextVideo.fps
            currentScript?.recording = recording
        }
        persistCaptureSettings()
    }

    private func updateCanvas(_ nextCanvas: CanvasSpec) {
        let resized = nextCanvas.width != canvas.width || nextCanvas.height != canvas.height || nextCanvas.inset != canvas.inset
            || nextCanvas.frame != canvas.frame || nextCanvas.contentWidth != canvas.contentWidth
        canvas = nextCanvas
        if resized {
            effects.camera = CameraState(scale: 1, focus: CGPoint(x: nextCanvas.pageWidth / 2, y: nextCanvas.pageHeight / 2))
            effects.pointer.visible = false
            browser.surface?.updateCamera()
        }
    }

    func rememberRecordingSettings(_ spec: RecordingSpec) {
        recordingSettings = spec
        recordingSettings.output = nil
        persistCaptureSettings()
    }

    private func persistCaptureSettings() {
        if let data = try? JSONEncoder().encode(CaptureSettings(canvas: canvas, video: recordingSettings)) {
            UserDefaults.standard.set(data, forKey: "captureSettings")
        }
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
        guard !isPreparing, !isFinishing else { return }
        Task { @MainActor in
            do {
                if isRecording { _ = try await recorder.stop() }
                else { try await recorder.start(recordingSettings) }
            } catch { report(error) }
        }
    }

    func navigate(_ url: String) {
        guard !isPlaying, !isFinishing, !isPreparing else { return }
        clearStoryboard()
        Task { @MainActor in
            do { try await browser.open(url) }
            catch { report(error) }
        }
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
        statusText = "Needs attention"
        toasts.show("Something needs attention", message: error.localizedDescription, kind: .error)
        FileHandle.standardError.write(Data("Showtime: \(error.localizedDescription)\n".utf8))
    }

    func copyForAgent(_ text: String, title: String) {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(text, forType: .string) {
            toasts.show(title, message: "Paste it into your agent to continue.")
        }
    }

    func revealExport() {
        if let lastExportURL { NSWorkspace.shared.activateFileViewerSelecting([lastExportURL]) }
        else {
            try? FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(exportFolder)
        }
    }

    func chromeImage(scale: Double) throws -> CGImage {
        let width = canvas.layout.screen.width, scale = max(1, scale)
        let key = "\(displayTitle)|\(displayURL)|\(width)|\(scale)|\(canvas.browserTheme)|\(faviconRevision)"
        if key == chromeCacheKey, let chromeCache { return chromeCache }
        let renderer = ImageRenderer(content: BrowserChromeView(model: self, exporting: true)
            .frame(width: width, height: CanvasSpec.chromeHeight)
            .environment(\.colorScheme, .light))
        renderer.scale = scale
        guard let image = renderer.cgImage else { throw ShowtimeError("Could not render the browser chrome.") }
        chromeCacheKey = key
        chromeCache = image
        return image
    }

    func screenshot(to path: String) async throws -> URL {
        let image = try await browser.snapshot()
        let frame = try SceneCompositor.render(model: self, webImage: image, width: recordingSettings.width, height: recordingSettings.height)
        let url = try OutputFiles.newURL(path: path, defaultFolder: exportFolder, ext: "png")
        let data = NSBitmapImageRep(cgImage: frame).representation(using: .png, properties: [:])
        guard let data else { throw ShowtimeError("PNG encoding failed.") }
        try OutputFiles.writeNew(data, to: url)
        return url
    }

    func studioScreenshot(to path: String, nativeOnly: Bool = false) async throws -> URL {
        // Include AppKit's real titlebar, toolbar, and traffic lights. The web
        // surface is composed separately because WKWebView renders out of process.
        guard let contentView = window?.contentView, let stageView, stageView.bounds.width > 0 else { throw ShowtimeError("The studio window is not ready.") }
        let content = contentView.superview ?? contentView
        let webImage = try await browser.snapshot()
        content.layoutSubtreeIfNeeded()
        guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw ShowtimeError("Could not capture the native studio controls.") }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        if nativeOnly || mode == .director, let data = bitmap.representation(using: .png, properties: [:]) {
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
        context.addPath(CGPath(roundedRect: captureFrame, cornerWidth: 14, cornerHeight: 14, transform: nil)); context.clip()
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

private struct CaptureSettings: Codable {
    let canvas: CanvasSpec
    let video: RecordingSpec
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
