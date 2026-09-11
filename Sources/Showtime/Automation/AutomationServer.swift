import AppKit
import Network
import ShowtimeCore

struct HTTPResponse {
    var status: Int = 200
    var contentType = "application/json; charset=utf-8"
    var body: Data

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]))
            ?? Data("{\"error\":\"Response encoding failed\"}".utf8)
        return HTTPResponse(status: status, body: data)
    }

    var data: Data {
        let reasons = [200: "OK", 202: "Accepted", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 409: "Conflict", 413: "Content Too Large", 500: "Internal Server Error", 503: "Service Unavailable"]
        let header = "HTTP/1.1 \(status) \(reasons[status] ?? "Error")\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\n\r\n"
        return Data(header.utf8) + body
    }
}

// After setup, all mutable connection state is confined to `queue`.
final class HTTPSession: @unchecked Sendable {
    let id = UUID()
    let connection: NWConnection
    let queue: DispatchQueue
    var buffer = Data()
    var done = false
    var timeout: DispatchWorkItem?
    var onClose: (() -> Void)?
    let handle: (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void

    init(connection: NWConnection, queue: DispatchQueue, handle: @escaping (HTTPRequest, @escaping (HTTPResponse) -> Void) -> Void) {
        self.connection = connection; self.queue = queue; self.handle = handle
    }

    func start() {
        queue.async { [weak self] in self?.startOnQueue() }
    }

    private func startOnQueue() {
        let timeout = DispatchWorkItem { [weak self] in self?.close() }
        self.timeout = timeout
        queue.asyncAfter(deadline: .now() + 15, execute: timeout)
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.close() }
            if case .cancelled = state { self?.onClose?() }
        }
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, finished, error in
            guard let self, !self.done else { return }
            if let data { self.buffer.append(data) }
            do {
                guard self.buffer.count <= HTTPParser.maximumBody + HTTPParser.maximumHeader else { throw ShowtimeError("Request body is too large.") }
                if let request = try HTTPParser.parse(self.buffer) {
                    self.done = true
                    self.timeout?.cancel()
                    self.buffer = Data()
                    self.handle(request) { [weak self] response in self?.send(response) }
                } else if finished || error != nil { self.close() }
                else { self.receive() }
            } catch { self.done = true; self.send(.json(["error": error.localizedDescription], status: 400)) }
        }
    }

    func send(_ response: HTTPResponse) {
        queue.async { [weak self] in
            guard let self else { return }
            self.connection.send(content: response.data, completion: .contentProcessed { [weak self] _ in self?.close() })
        }
    }

    func close() {
        done = true; timeout?.cancel(); connection.cancel(); onClose?(); onClose = nil
    }
}

@MainActor
final class AutomationServer {
    unowned let model: StudioModel
    private let queue = DispatchQueue(label: "studio.showtime.loopback", qos: .userInitiated)
    private var listener: NWListener?
    private var sessions: [UUID: HTTPSession] = [:]
    private(set) var token = UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")

    init(model: StudioModel) { self.model = model }

    func start(port: UInt16) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    do {
                        let actualPort = self.listener?.port?.rawValue ?? port
                        try self.writeConnection(port: actualPort)
                        self.model.serverBecameReady(port: actualPort)
                    } catch { self.model.report(error); self.stop() }
                case .failed(let error):
                    self.model.agentReady = false
                    self.model.report(ShowtimeError("Local control server could not start on port \(port): \(error.localizedDescription). Set SHOWTIME_PORT to use another port."))
                default: break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                guard self.sessions.count < 32 else { connection.cancel(); return }
                let session = HTTPSession(connection: connection, queue: self.queue) { [weak self] request, respond in
                    Task { @MainActor in
                        guard let self else { respond(.json(["error": "Showtime is closing"], status: 503)); return }
                        respond(await self.handle(request))
                    }
                }
                self.sessions[session.id] = session
                session.onClose = { [weak self, weak session] in
                    Task { @MainActor in if let id = session?.id { self?.sessions.removeValue(forKey: id) } }
                }
                session.start()
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel(); listener = nil
        let active = Array(sessions.values)
        sessions.removeAll()
        for session in active { queue.async { session.close() } }
        if let data = try? Data(contentsOf: model.connectionFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["token"] as? String == token {
            try? FileManager.default.removeItem(at: model.connectionFile)
        }
        model.agentReady = false
    }

    private func writeConnection(port: UInt16) throws {
        let file = model.connectionFile
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let object: [String: Any] = ["url": "http://127.0.0.1:\(port)", "token": token, "pid": ProcessInfo.processInfo.processIdentifier,
                                    "version": 1, "appVersion": AppVersion.number, "app": "Showtime"]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let path = String(request.path.split(separator: "?", maxSplits: 1)[0])
        let hosts = ["127.0.0.1:\(model.agentPort)", "localhost:\(model.agentPort)"]
        guard let host = request.headers["host"], hosts.contains(host.lowercased()) else {
            return .json(["error": "Use the loopback host and port from connection.json."], status: 403)
        }
        if path == "/api/live", request.method == "GET" {
            return .json(["service": "Showtime", "status": "ok", "version": AppVersion.number, "protocolVersion": 1])
        }
        if path == "/health", request.method == "GET" { return .json(["service": "Showtime", "version": 1, "appVersion": AppVersion.number]) }
        if path == "/" || path.hasPrefix("/demo") { return serveDemo(path, method: request.method) }
        guard request.headers["origin"] == nil else { return .json(["error": "Browser-origin control requests are not accepted. Use the CLI or MCP bridge."], status: 403) }
        guard request.headers["authorization"] == "Bearer \(token)" else { return .json(["error": "A valid Showtime session token is required."], status: 401) }
        guard ["GET", "POST"].contains(request.method) else { return .json(["error": "Use GET or POST."], status: 405) }
        do {
            switch (request.method, path) {
            case ("GET", "/v1/status"):
                return .json(status())
            case ("GET", "/v1/inspect"):
                let inspection = try await model.browser.inspect()
                if !model.isBusy { model.playbackMode = .design }
                model.activity.inspected()
                return .json(inspection)
            case ("GET", "/v1/scripts/demo"):
                guard let url = AppResources.bundle.url(forResource: "orbit-launch", withExtension: "json", subdirectory: "Scripts") else { throw ShowtimeError("Bundled script is missing.") }
                return HTTPResponse(body: try Data(contentsOf: url))
            case ("POST", "/v1/run"):
                let script = try JSONDecoder().decode(FilmScript.self, from: request.body)
                let id = try model.director.run(script, source: .agent)
                return .json(["job": id, "status": "running", "poll": "/v1/jobs/\(id)"], status: 202)
            case ("POST", "/v1/design"):
                let object = try dictionary(request.body)
                guard Set(object.keys).isSubset(of: ["step", "screenshot"]), let step = object["step"] as? [String: Any] else {
                    throw ShowtimeError("Design accepts step and an optional screenshot path. Use the same action object in a script's steps.")
                }
                if let screenshot = object["screenshot"], !(screenshot is String) {
                    throw ShowtimeError("screenshot must be a PNG path string.")
                }
                let action = try JSONDecoder().decode(Action.self, from: JSONSerialization.data(withJSONObject: step))
                let id = try model.director.run(FilmScript(name: action.displayLabel, steps: [action]), singleAction: true,
                                                source: .agent, mode: .design, screenshot: object["screenshot"] as? String)
                return .json(["job": id, "status": "running", "mode": "design", "poll": "/v1/jobs/\(id)"], status: 202)
            case ("POST", "/v1/rehearse"), ("POST", "/v1/record"), ("POST", "/v1/validate"):
                let object = try dictionary(request.body)
                let validating = path == "/v1/validate"
                let allowed: Set<String> = validating ? ["script", "from", "to", "output", "screenshot", "mode"] : ["script", "from", "to", "output", "screenshot"]
                guard Set(object.keys).isSubset(of: allowed) else {
                    throw ShowtimeError("Playback accepts script, from, to, output, and screenshot; validate also accepts mode.")
                }
                let mode: PlaybackMode
                if path == "/v1/validate" {
                    guard object["mode"] == nil || object["mode"] is String,
                          let value = PlaybackMode(rawValue: object["mode"] as? String ?? "rehearse"), value != .design else {
                        throw ShowtimeError("Validate mode must be rehearse or record.")
                    }
                    mode = value
                } else { mode = path == "/v1/record" ? .record : .rehearse }
                let playback = try JSONDecoder().decode(PlaybackRequest.self, from: request.body)
                var script = playback.script
                let range = try playback.selectedRange()
                if mode == .record {
                    var video = try script.recording ?? model.recordingSettings.fitted(to: script.canvas ?? model.canvas)
                    guard let output = playback.output ?? video.output, !output.isEmpty else {
                        throw ShowtimeError("Recording requires a new MP4 output path.")
                    }
                    video.output = try OutputFiles.newURL(path: output, defaultFolder: model.exportFolder, ext: "mp4", createDirectory: false).path
                    script.recording = video
                } else {
                    guard playback.output == nil else { throw ShowtimeError("output is only used in record mode.") }
                    script.recording = nil
                }
                try script.validate(defaultCanvas: model.canvas)
                if let screenshot = playback.screenshot { _ = try OutputFiles.newURL(path: screenshot, defaultFolder: model.exportFolder, ext: "png", createDirectory: false) }
                if path == "/v1/validate" {
                    return .json(["valid": true, "mode": mode.rawValue, "name": script.name,
                                  "range": ["from": range.lowerBound + 1, "to": range.upperBound, "scriptSteps": script.steps.count],
                                  "steps": range.count, "setupSteps": script.setup.count])
                }
                let id = try model.director.run(script, source: .agent, mode: mode, range: range, screenshot: playback.screenshot)
                return .json(["job": id, "status": "running", "mode": mode.rawValue, "poll": "/v1/jobs/\(id)"], status: 202)
            case ("POST", "/v1/actions"), ("POST", "/v1/open"):
                var data = request.body
                if path == "/v1/open" {
                    var object = try dictionary(data)
                    object["action"] = "open"
                    data = try JSONSerialization.data(withJSONObject: object)
                }
                let action = try JSONDecoder().decode(Action.self, from: data)
                let script = FilmScript(name: action.displayLabel, steps: [action])
                let id = try model.director.run(script, singleAction: true, source: .agent)
                return .json(["job": id, "status": "running", "poll": "/v1/jobs/\(id)"], status: 202)
            case ("POST", "/v1/cancel"):
                if model.isPlaying { model.director.cancel(); return .json(["status": "stopping", "job": model.director.currentJobID ?? ""]) }
                if model.isRecording { return .json(try await model.recorder.stop().json) }
                return .json(["status": "idle"])
            case ("POST", "/v1/recording/start"):
                guard !model.isPlaying else { throw ShowtimeError("Wait for the current job before starting a manual recording.") }
                let spec = try merged(model.recordingSettings, patch: dictionary(request.body), allowed: ["width", "height", "fps", "output"])
                try await model.recorder.start(spec)
                return .json(["status": "recording"])
            case ("POST", "/v1/recording/stop"):
                guard !model.isPlaying else { throw ShowtimeError("A script is running. Use /v1/cancel to stop the take.") }
                return .json(try await model.recorder.stop().json)
            case ("POST", "/v1/screenshot"):
                let object = try dictionary(request.body)
                let path = object["output"] as? String ?? model.exportFolder.appendingPathComponent("Frame-\(UUID().uuidString.prefix(8)).png").path
                return .json(["path": try await model.screenshot(to: path).path])
            case ("POST", "/v1/app/quit"):
                guard !model.isBusy else { throw ShowtimeError("The director is busy. Finish the take before closing Showtime.") }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
                return .json(["status": "closing"])
            case ("POST", "/v1/studio/screenshot"):
                let object = try dictionary(request.body)
                let path = object["output"] as? String ?? model.exportFolder.appendingPathComponent("Studio-\(UUID().uuidString.prefix(8)).png").path
                return .json(["path": try await model.studioScreenshot(to: path, nativeOnly: object["nativeOnly"] as? Bool ?? false).path])
            case ("GET", "/v1/studio"):
                return .json(model.studioState)
            case ("GET", "/v1/settings"):
                return .json(model.captureState)
            case ("POST", "/v1/settings"):
                let object = try dictionary(request.body)
                guard Set(object.keys).isSubset(of: ["canvas", "video"]) else { throw ShowtimeError("Capture settings accept canvas and video objects.") }
                let canvas = try merged(model.canvas, patch: object["canvas"] ?? [:],
                                        allowed: ["width", "height", "inset", "backdrop", "glow", "glowRadius", "glowSize", "browserTheme", "frame", "contentWidth"], nullable: ["contentWidth"])
                let fitted = try model.recordingSettings.fitted(to: canvas)
                let video = try merged(fitted, patch: object["video"] ?? [:], allowed: ["width", "height", "fps"])
                try model.applyCapture(canvas: canvas, video: video)
                return .json(model.captureState)
            case ("POST", "/v1/studio"):
                let object = try dictionary(request.body)
                var mode: StudioMode?
                if let raw = object["mode"] as? String {
                    guard let parsed = StudioMode(rawValue: raw) else { throw ShowtimeError("Studio mode must be studio, theater, or director.") }
                    mode = parsed
                } else if let theater = object["theater"] as? Bool { mode = theater ? .theater : .studio }
                if mode == .director, model.isBusy { throw ShowtimeError("The director is busy. Finish the take before opening the setup page.") }
                var appearance: StudioAppearance?
                if let raw = object["theme"] as? String {
                    guard let parsed = StudioAppearance(rawValue: raw) else { throw ShowtimeError("Studio theme must be light or dark.") }
                    appearance = parsed
                }
                if let tab = object["inspector"] as? String {
                    guard ["Canvas", "Frame", "Cursor", "Text", "Export"].contains(tab) else { throw ShowtimeError("Inspector tab must be Canvas, Frame, Cursor, Text, or Export.") }
                    model.selectedInspector = tab
                    model.showInspector = true
                }
                if let visible = object["showInspector"] as? Bool { model.showInspector = visible }
                if let mode { model.mode = mode }
                if let appearance { model.appearance = appearance }
                return .json(model.studioState)
            case ("GET", "/v1/studio/window"):
                guard let window = model.window else { throw ShowtimeError("The studio window is not ready.") }
                return .json(StudioWindow.state(window))
            case ("POST", "/v1/studio/window"):
                guard !model.isBusy else { throw ShowtimeError("The director is busy. Finish the take before changing the window.") }
                guard let window = model.window else { throw ShowtimeError("The studio window is not ready.") }
                try StudioWindow.perform(dictionary(request.body), on: window)
                return .json(StudioWindow.state(window))
            default:
                if request.method == "GET", path.hasPrefix("/v1/jobs/") {
                    let id = String(path.dropFirst("/v1/jobs/".count))
                    if let job = model.director.jobs[id] { return .json(job.json) }
                    return .json(["error": "Job not found. Showtime retains the most recent 40 jobs."], status: 404)
                }
                return .json(["error": "Endpoint not found."], status: 404)
            }
        } catch {
            model.report(error)
            let busy = error.localizedDescription.contains("busy") || error.localizedDescription.contains("already") || error.localizedDescription.contains("Wait for")
            return .json(["error": error.localizedDescription], status: busy ? 409 : 400)
        }
    }

    private func dictionary(_ data: Data) throws -> [String: Any] {
        if data.isEmpty { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ShowtimeError("Expected a JSON object.") }
        return object
    }

    private func merged<T: Codable>(_ current: T, patch: Any, allowed: Set<String>, nullable: Set<String> = []) throws -> T {
        guard let patch = patch as? [String: Any], Set(patch.keys).isSubset(of: allowed) else {
            throw ShowtimeError("Expected settings with these fields: \(allowed.sorted().joined(separator: ", ")).")
        }
        var object = try dictionary(JSONEncoder().encode(current))
        for (key, value) in patch {
            guard !(value is NSNull) || nullable.contains(key) else { throw ShowtimeError("Setting \(key) cannot be null.") }
            object[key] = value
        }
        return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func status() -> [String: Any] {
        var object: [String: Any] = [
            "app": "Showtime", "version": 1, "appVersion": AppVersion.number, "ready": model.browser.ready,
            "playing": model.isPlaying, "designing": model.isDesigning, "busy": model.isBusy, "workflow": model.playbackMode.rawValue,
            "recording": model.isRecording, "preparing": model.isPreparing, "finishing": model.isFinishing,
            "title": model.actualTitle, "url": model.actualURL,
            "navigation": ["canGoBack": model.canGoBack, "canGoForward": model.canGoForward, "loading": model.isLoading,
                           "canNavigate": model.canNavigate],
            "displayTitle": model.displayTitle, "displayURL": model.displayURL,
            "favicon": ["loaded": model.favicon != nil],
            "viewport": ["width": model.browser.webView.bounds.width, "height": model.browser.webView.bounds.height],
            "canvas": model.captureState["canvas"]!,
            "video": model.captureState["video"]!,
            "storyboard": ["name": model.scriptName, "cues": model.currentScript?.steps.count ?? 0],
            "camera": ["scale": model.effects.camera.scale, "x": model.effects.camera.focus.x, "y": model.effects.camera.focus.y,
                       "offsetX": model.effects.camera.offset.x, "offsetY": model.effects.camera.offset.y, "rotation": model.effects.camera.rotation,
                       "flipX": model.effects.camera.flipX, "flipY": model.effects.camera.flipY],
            "cursor": ["style": model.effects.pointer.style, "visible": model.effects.pointer.visible, "size": model.effects.pointer.size,
                       "x": model.effects.pointer.point.x, "y": model.effects.pointer.point.y, "color": model.effects.pointer.color,
                       "hotspotX": model.effects.pointer.hotspot.x, "hotspotY": model.effects.pointer.hotspot.y,
                       "clickEffect": model.effects.pointer.clickEffect],
            "studio": model.studioState,
            "director": model.activity.state.json,
            "elapsed": model.elapsed, "status": model.statusText,
        ]
        if let job = model.director.currentJobID { object["job"] = job }
        if let output = model.lastExportURL { object["lastExport"] = output.path }
        if let error = model.errorMessage { object["error"] = error }
        if let caption = model.effects.caption {
            object["caption"] = ["text": caption.text, "style": caption.style, "position": caption.position,
                                 "duration": caption.duration, "held": caption.held]
        }
        if let window = model.window { object["windowNumber"] = window.windowNumber }
        return object
    }

    private func serveDemo(_ path: String, method: String) -> HTTPResponse {
        guard method == "GET" else { return .json(["error": "Method not allowed."], status: 405) }
        let files: [String: (String, String)] = [
            "/": ("index.html", "text/html; charset=utf-8"), "/demo": ("index.html", "text/html; charset=utf-8"),
            "/demo/": ("index.html", "text/html; charset=utf-8"), "/demo/index.html": ("index.html", "text/html; charset=utf-8"),
            "/demo/style.css": ("style.css", "text/css; charset=utf-8"),
            "/demo/app.js": ("app.js", "application/javascript; charset=utf-8"),
            "/demo/favicon.svg": ("favicon.svg", "image/svg+xml"),
        ]
        guard let (name, mime) = files[path], let folder = AppResources.bundle.url(forResource: "Demo", withExtension: nil),
              let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else {
            return .json(["error": "Demo asset not found."], status: 404)
        }
        return HTTPResponse(contentType: mime, body: data)
    }
}
