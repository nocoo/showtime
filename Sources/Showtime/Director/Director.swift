import AppKit
import QuartzCore
import ShowtimeCore

struct JobRecord {
    var id = UUID().uuidString.lowercased()
    var name: String
    var status = "running"
    var step = 0
    var total: Int
    var mode: PlaybackMode = .rehearse
    var phase = "preparing"
    var completed = 0
    var from = 1
    var to = 1
    var scriptTotal = 1
    var setupStep = 0
    var setupTotal = 0
    var screenshot: String?
    var current: Action?
    var cueStarted: Date?
    var started = Date()
    var finished: Date?
    var error: String?
    var output: String?
    var results: [[String: Any]] = []

    var json: [String: Any] {
        var value: [String: Any] = ["id": id, "name": name, "status": status, "step": step, "total": total,
                                    "mode": mode.rawValue, "phase": phase, "completed": completed,
                                    "range": ["from": from, "to": to, "scriptSteps": scriptTotal],
                                    "setup": ["step": setupStep, "total": setupTotal],
                                    "elapsed": max(0, (finished ?? Date()).timeIntervalSince(started)),
                                    "started": ISO8601DateFormatter().string(from: started), "results": results]
        if let finished { value["finished"] = ISO8601DateFormatter().string(from: finished) }
        if let error { value["error"] = error }
        if let output { value["output"] = output }
        if let screenshot { value["screenshot"] = screenshot }
        if let current {
            var cue: [String: Any] = ["action": current.action.rawValue, "label": current.displayLabel,
                                       "elapsed": max(0, (finished ?? Date()).timeIntervalSince(cueStarted ?? started))]
            if let id = current.id { cue["id"] = id }
            if let duration = current.duration { cue["duration"] = duration }
            value["current"] = cue
        }
        return value
    }
}

@MainActor
final class Director {
    unowned let model: StudioModel
    private(set) var jobs: [String: JobRecord] = [:]
    private(set) var currentJobID: String?
    private var task: Task<Void, Never>?
    private var abortError: Error?

    init(model: StudioModel) { self.model = model }

    @discardableResult
    func run(_ original: FilmScript, singleAction: Bool = false, source: DirectorActivitySource = .local,
             mode requestedMode: PlaybackMode? = nil, range requestedRange: Range<Int>? = nil, screenshot: String? = nil) throws -> String {
        var script = original
        let mode = requestedMode ?? (singleAction ? .design : script.recording == nil ? .rehearse : .record)
        if mode != .record { script.recording = nil }
        try script.validate(defaultCanvas: model.canvas)
        guard !model.isBusy else { throw ShowtimeError("The director is busy. Wait for the current job or stop it first.") }
        if mode == .design, script.steps.count != 1 || !script.setup.isEmpty {
            throw ShowtimeError("Design previews accept one action. Use rehearse or record for scripts.")
        }
        let range = requestedRange ?? script.steps.indices
        guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= script.steps.count else { throw ShowtimeError("Invalid playback range.") }
        if mode == .record {
            var recording = try script.recording ?? model.recordingSettings.fitted(to: script.canvas ?? model.canvas)
            recording.output = try OutputFiles.newURL(path: recording.output, defaultFolder: model.exportFolder, ext: "mp4").path
            script.recording = recording
        }
        if let screenshot { _ = try OutputFiles.newURL(path: screenshot, defaultFolder: model.exportFolder, ext: "png") }
        if mode != .design {
            try model.stageScript(script)
            model.effects.reset(pageSize: model.pageSize)
        } else if script.steps.first?.action == .open {
            model.clearStoryboard()
        }
        let job = JobRecord(name: script.name, total: range.count, mode: mode, from: range.lowerBound + 1,
                            to: range.upperBound, scriptTotal: script.steps.count, setupTotal: script.setup.count)
        if jobs.count >= 40, let oldest = jobs.values.filter({ $0.status != "running" }).min(by: { $0.started < $1.started }) { jobs.removeValue(forKey: oldest.id) }
        jobs[job.id] = job
        currentJobID = job.id
        abortError = nil
        model.errorMessage = nil
        model.toasts.dismiss()
        if model.mode == .director { model.mode = .theater }
        model.playbackMode = mode
        model.activity.begin(script, id: job.id, source: source, mode: mode, range: range)
        model.isPlaying = true
        task = Task { @MainActor in await self.execute(script, jobID: job.id, mode: mode, range: range, screenshot: screenshot) }
        return job.id
    }

    func cancel() { task?.cancel() }
    func abort(_ error: Error) { abortError = error; cancel() }
    func waitUntilStopped() async { await task?.value }

    private func execute(_ script: FilmScript, jobID: String, mode: PlaybackMode, range: Range<Int>, screenshot: String?) async {
        var ownsRecording = false
        do {
            if script.canvas != nil {
                try await Task.sleep(for: .milliseconds(180))
                model.browser.surface?.layoutSubtreeIfNeeded()
            }
            for (index, step) in script.setup.enumerated() {
                try Task.checkCancellation()
                jobs[jobID]?.phase = "setup"
                jobs[jobID]?.setupStep = index + 1
                jobs[jobID]?.current = step
                jobs[jobID]?.cueStarted = Date()
                model.statusText = "Setup · \(step.displayLabel)"
                model.activity.beginSetup(step, index: index, jobID: jobID)
                let started = CACurrentMediaTime()
                let value = try await perform(step)
                var result: [String: Any] = ["phase": "setup", "step": index + 1, "action": step.action.rawValue,
                                            "label": step.displayLabel, "duration": CACurrentMediaTime() - started]
                if let id = step.id { result["id"] = id }
                if let value { result["value"] = value }
                jobs[jobID]?.results.append(result)
            }
            var startIndex = range.lowerBound
            // Navigation is preparation, so a recorded film opens on a fully rendered first frame.
            if script.recording != nil, startIndex == 0, script.steps.first?.action == .open {
                try await runStep(script.steps[0], index: 0, script: script, range: range, jobID: jobID)
                startIndex = 1
            }
            if let recording = script.recording {
                try Task.checkCancellation()
                jobs[jobID]?.phase = "preparing"
                try await model.recorder.start(recording)
                ownsRecording = true
            }
            jobs[jobID]?.phase = "running"
            for index in startIndex..<range.upperBound {
                try Task.checkCancellation()
                try await runStep(script.steps[index], index: index, script: script, range: range, jobID: jobID)
            }
            if let screenshot { jobs[jobID]?.screenshot = try await model.screenshot(to: screenshot).path }
            if ownsRecording {
                jobs[jobID]?.phase = "saving"
                let result = try await Task { @MainActor in try await self.model.recorder.stop() }.value
                jobs[jobID]?.output = result.url.path
                jobs[jobID]?.results.append(["recording": result.json])
            }
            jobs[jobID]?.status = "completed"
            model.statusText = ownsRecording ? "A good take. Ready to share." : mode == .design ? "Design preview ready" : "Rehearsal complete"
        } catch {
            let cancelled = error is CancellationError && abortError == nil
            let failurePhase = jobs[jobID]?.phase
            if ownsRecording && model.isRecording {
                jobs[jobID]?.phase = "saving"
                // Finish on a fresh, uncancelled task so an interrupted take is still a playable MP4.
                let result = await Task { @MainActor in try? await self.model.recorder.stop() }.value
                jobs[jobID]?.output = result?.url.path
                if let result { jobs[jobID]?.results.append(["recording": result.json, "partial": true]) }
            }
            jobs[jobID]?.status = cancelled ? "cancelled" : "failed"
            if !cancelled {
                let failure = abortError ?? error
                let job = jobs[jobID]!
                let position = failurePhase == "setup" ? "Setup \(job.setupStep)" : "Step \(job.step)"
                let cue = job.current.map { " (\($0.id ?? $0.action.rawValue))" } ?? ""
                jobs[jobID]?.error = "\(position)\(cue): \(failure.localizedDescription)"
                model.report(failure)
            } else { model.statusText = "Take stopped" }
        }
        jobs[jobID]?.finished = Date()
        let status = jobs[jobID]?.status ?? "failed"
        jobs[jobID]?.phase = status
        let finalPhase: DirectorActivityPhase = status == "completed" ? .completed : status == "cancelled" ? .stopped : .failed
        model.activity.finish(finalPhase, output: jobs[jobID]?.output)
        if let output = jobs[jobID]?.output, let job = jobs[jobID] {
            let sidecar = URL(fileURLWithPath: output).deletingPathExtension().appendingPathExtension("json")
            if let data = try? JSONSerialization.data(withJSONObject: job.json, options: [.prettyPrinted, .sortedKeys]) {
                try? OutputFiles.writeNew(data, to: sidecar)
            }
        }
        model.isPlaying = false
        currentJobID = nil
        task = nil
    }

    private func runStep(_ step: Action, index: Int, script: FilmScript, range: Range<Int>, jobID: String) async throws {
        model.activity.beginCue(step, index: index, script: script, range: range, jobID: jobID)
        model.currentStep = index
        model.statusText = step.displayLabel
        jobs[jobID]?.step = index + 1
        jobs[jobID]?.current = step
        jobs[jobID]?.cueStarted = Date()
        let started = CACurrentMediaTime()
        let value = try await perform(step)
        var result: [String: Any] = ["phase": "steps", "step": index + 1, "action": step.action.rawValue, "label": step.displayLabel,
                                     "duration": CACurrentMediaTime() - started]
        if let id = step.id { result["id"] = id }
        if let value { result["value"] = value }
        jobs[jobID]?.results.append(result)
        jobs[jobID]?.completed += 1
        model.activity.completeCue(completed: jobs[jobID]?.completed ?? 0)
    }

    func perform(_ step: Action) async throws -> Any? {
        try Task.checkCancellation()
        let browser = model.browser
        let effects = model.effects
        switch step.action {
        case .open:
            try await browser.open(step.url!, title: step.title, displayURL: step.displayURL, timeout: step.timeout ?? 30)
            return ["url": model.actualURL, "title": model.actualTitle]
        case .metadata:
            model.titleOverride = step.title ?? ""
            model.urlOverride = step.displayURL ?? ""
        case .move:
            let point = try await target(step)
            try await move(to: point, duration: step.duration ?? 0.75, curve: step.easing, arc: step.arc)
        case .click, .doubleClick:
            let point = try await target(step)
            try await move(to: point, duration: step.duration ?? 0.55, curve: step.easing, arc: step.arc)
            let count = step.action == .doubleClick ? 2 : 1
            for i in 1...count {
                effects.pointer.pressed = true
                try browser.mouse(.leftMouseDown, at: point, clicks: i)
                do { try await Task.sleep(for: .milliseconds(65)) }
                catch { try? browser.mouse(.leftMouseUp, at: point, clicks: i); effects.pointer.pressed = false; throw error }
                try browser.mouse(.leftMouseUp, at: point, clicks: i)
                effects.pointer.pressed = false
                effects.click(at: point)
                if i < count { try await Task.sleep(for: .milliseconds(75)) }
            }
            try await Task.sleep(for: .milliseconds(100))
            return ["x": point.x, "y": point.y, "input": "native"]
        case .drag:
            let from = try await target(step)
            let to = try await browser.target(selector: step.toSelector, x: step.toX, y: step.toY, scroll: false)
            try await move(to: from, duration: 0.4, curve: step.easing, arc: step.arc)
            effects.pointer.pressed = true
            try browser.mouse(.leftMouseDown, at: from)
            defer { try? browser.mouse(.leftMouseUp, at: effects.pointer.point); effects.pointer.pressed = false }
            try await animate(duration: step.duration ?? 1.2, curve: step.easing) { p in
                let point = CGPoint(x: from.x + (to.x - from.x) * p, y: from.y + (to.y - from.y) * p)
                effects.pointer.point = point
                try browser.mouse(.leftMouseDragged, at: point)
            }
        case .scroll:
            let point: CGPoint
            if step.selector != nil || step.x != nil { point = try await target(step) }
            else { point = CGPoint(x: model.pageSize.width * 0.66, y: model.pageSize.height * 0.65) }
            try browser.scroll(at: point, deltaX: 0, deltaY: 0, phase: .began)
            defer { try? browser.scroll(at: point, deltaX: 0, deltaY: 0, phase: Task.isCancelled ? .cancelled : .ended) }
            var lastX: Double = 0, lastY: Double = 0
            try await animate(duration: step.duration ?? 0.9, curve: step.easing) { p in
                let nextX = ((step.deltaX ?? 0) * p).rounded(), nextY = ((step.deltaY ?? 480) * p).rounded()
                try browser.scroll(at: point, deltaX: nextX - lastX, deltaY: nextY - lastY, phase: .changed)
                lastX = nextX; lastY = nextY
            }
        case .type:
            if step.selector != nil || step.x != nil {
                var click = step; click.action = .click; click.duration = 0.35
                _ = try await perform(click)
            }
            if step.clear == true {
                try browser.sendKey("a", modifiers: ["command"])
                try browser.sendKey("backspace")
                try await Task.sleep(for: .milliseconds(60))
            }
            for character in step.text! {
                try Task.checkCancellation()
                try browser.insertText(String(character))
                if (step.delay ?? 0.045) > 0 { try await Task.sleep(for: .seconds(step.delay ?? 0.045)) }
            }
        case .key:
            try browser.sendKey(step.key!, modifiers: step.modifiers ?? [])
            try await Task.sleep(for: .milliseconds(80))
        case .wait:
            try await Task.sleep(for: .seconds(step.duration ?? 1))
        case .waitFor:
            let expression = step.script ?? "(() => { const e=document.querySelector(\(BrowserEngine.literal(step.selector!))); if(!e) return false; const r=e.getBoundingClientRect(),s=getComputedStyle(e); return r.width>0 && r.height>0 && s.visibility!=='hidden' && s.display!=='none'; })()"
            let deadline = CACurrentMediaTime() + (step.timeout ?? 10)
            while true {
                try Task.checkCancellation()
                if let result = try await browser.evaluate(expression) as? Bool, result { break }
                guard CACurrentMediaTime() < deadline else { throw ShowtimeError("Timed out waiting for \(step.selector ?? "the JavaScript condition").") }
                try await Task.sleep(for: .milliseconds(80))
            }
        case .zoom, .camera:
            let start = effects.camera
            var end = start
            end.scale = step.scale ?? (step.action == .zoom ? 1 : start.scale)
            if step.selector != nil || step.x != nil { end.focus = try await target(step) }
            end.offset = CGPoint(x: step.offsetX ?? start.offset.x, y: step.offsetY ?? start.offset.y)
            end.rotation = step.rotation ?? start.rotation
            end.flipX = step.flipX ?? start.flipX; end.flipY = step.flipY ?? start.flipY
            if !end.isIdentity, start.isIdentity {
                let image = try await browser.snapshot()
                browser.surface?.updateCamera(image: image)
            }
            try await animate(duration: step.duration ?? 1, curve: step.easing) { p in
                var frame = end
                frame.scale = start.scale + (end.scale - start.scale) * p
                frame.focus = CGPoint(x: start.focus.x + (end.focus.x - start.focus.x) * p, y: start.focus.y + (end.focus.y - start.focus.y) * p)
                frame.offset = CGPoint(x: start.offset.x + (end.offset.x - start.offset.x) * p, y: start.offset.y + (end.offset.y - start.offset.y) * p)
                frame.rotation = start.rotation + (end.rotation - start.rotation) * p
                effects.camera = frame
                browser.surface?.updateCamera()
            }
        case .caption:
            effects.showCaption(step, held: model.isDesigning)
        case .cursor:
            if let style = step.style { effects.pointer.style = style }
            if let size = step.size { effects.pointer.size = size }
            if let color = step.color { effects.pointer.color = color }
            if let visible = step.visible { effects.pointer.visible = visible }
            if let clickEffect = step.clickEffect { effects.pointer.clickEffect = clickEffect }
            if let x = step.hotspotX { effects.pointer.hotspot.x = x }
            if let y = step.hotspotY { effects.pointer.hotspot.y = y }
            if let path = step.image {
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                guard (values.fileSize ?? 0) <= 5_000_000, let image = NSImage(contentsOf: url) else {
                    throw ShowtimeError("Custom cursors must be valid images smaller than 5 MB.")
                }
                var rect = CGRect(origin: .zero, size: image.size)
                guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil), cg.width <= 2048, cg.height <= 2048 else {
                    throw ShowtimeError("Custom cursor dimensions must be at most 2048 × 2048.")
                }
                effects.pointer.customImage = cg
                effects.pointer.customImagePath = url.path
            }
        case .marker:
            model.statusText = step.text ?? step.label ?? "Scene"
        case .assert:
            let value = try await browser.evaluate(step.script!) ?? NSNull()
            let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
            let actual = try JSONDecoder().decode(JSONValue.self, from: data)
            guard actual == (step.equals ?? .bool(true)) else {
                throw ShowtimeError("Assertion failed: \(step.script!). Expected \(step.equals?.foundation ?? true), received \(value).")
            }
            return ["passed": true, "actual": value]
        case .evaluate:
            return try await browser.evaluate(step.script!) ?? NSNull()
        case .screenshot:
            return ["path": try await model.screenshot(to: step.output!).path]
        case .parallel:
            try await withThrowingTaskGroup(of: Void.self) { group in
                for action in step.steps! {
                    group.addTask { @MainActor in _ = try await self.perform(action) }
                }
                try await group.waitForAll()
            }
        }
        return nil
    }

    private func target(_ step: Action) async throws -> CGPoint {
        try await model.browser.target(selector: step.selector, x: step.x, y: step.y)
    }

    private func move(to end: CGPoint, duration: Double, curve: String?, arc: Double?) async throws {
        let start = model.effects.pointer.point
        model.effects.pointer.visible = true
        try await animate(duration: duration, curve: curve) { p in
            let bow = sin(p * .pi) * (arc ?? -12)
            let point = CGPoint(x: start.x + (end.x - start.x) * p, y: start.y + (end.y - start.y) * p + bow)
            self.model.effects.pointer.point = point
            try self.model.browser.mouse(.mouseMoved, at: point)
        }
    }

    private func animate(duration: Double, curve: String?, update: (Double) throws -> Void) async throws {
        if duration <= 0 { try update(1); return }
        let start = CACurrentMediaTime()
        let interval = 1.0 / 60
        while true {
            try Task.checkCancellation()
            let progress = min(1, (CACurrentMediaTime() - start) / duration)
            try update(Motion.ease(progress, curve: curve ?? "cinematic"))
            if progress >= 1 { break }
            // Keep a steady cadence without accumulating work time or replaying
            // a burst of old input events after a busy frame.
            let now = CACurrentMediaTime()
            let nextTick = start + (floor((now - start) / interval) + 1) * interval
            try await Task.sleep(for: .seconds(nextTick - now))
        }
    }
}
