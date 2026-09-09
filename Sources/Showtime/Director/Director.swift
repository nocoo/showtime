import AppKit
import QuartzCore
import ShowtimeCore

struct JobRecord {
    var id = UUID().uuidString.lowercased()
    var name: String
    var status = "running"
    var step = 0
    var total: Int
    var started = Date()
    var finished: Date?
    var error: String?
    var output: String?
    var results: [[String: Any]] = []

    var json: [String: Any] {
        var value: [String: Any] = ["id": id, "name": name, "status": status, "step": step, "total": total,
                                    "started": ISO8601DateFormatter().string(from: started), "results": results]
        if let finished { value["finished"] = ISO8601DateFormatter().string(from: finished) }
        if let error { value["error"] = error }
        if let output { value["output"] = output }
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
    func run(_ script: FilmScript, singleAction: Bool = false) throws -> String {
        try script.validate(defaultCanvas: model.canvas)
        guard !model.isPlaying, !model.isFinishing, !model.isPreparing else { throw ShowtimeError("The director is busy. Wait for the current job or stop it first.") }
        guard !(model.isRecording && script.recording != nil) else { throw ShowtimeError("A recording is already in progress.") }
        guard !(model.isRecording && script.canvas != nil && script.canvas != model.canvas) else {
            throw ShowtimeError("Canvas dimensions cannot change during a recording.")
        }
        let job = JobRecord(name: script.name, total: script.steps.count)
        if jobs.count >= 40, let oldest = jobs.values.filter({ $0.status != "running" }).min(by: { $0.started < $1.started }) { jobs.removeValue(forKey: oldest.id) }
        jobs[job.id] = job
        currentJobID = job.id
        abortError = nil
        model.errorMessage = nil
        model.isPlaying = true
        if !singleAction {
            model.currentScript = script
            model.scriptName = script.name
            model.effects.reset()
        }
        task = Task { @MainActor in await self.execute(script, jobID: job.id) }
        return job.id
    }

    func cancel() { task?.cancel() }
    func abort(_ error: Error) { abortError = error; cancel() }
    func waitUntilStopped() async { await task?.value }

    private func execute(_ script: FilmScript, jobID: String) async {
        var ownsRecording = false
        do {
            if let canvas = script.canvas {
                model.canvas = canvas
                try await Task.sleep(for: .milliseconds(180))
                model.browser.surface?.layoutSubtreeIfNeeded()
            }
            var startIndex = 0
            // Navigation is preparation, so a recorded film opens on a fully rendered first frame.
            if script.recording != nil, script.steps.first?.action == .open {
                try await runStep(script.steps[0], index: 0, jobID: jobID)
                startIndex = 1
            }
            if let recording = script.recording {
                try await model.recorder.start(recording)
                ownsRecording = true
            }
            for index in startIndex..<script.steps.count {
                try Task.checkCancellation()
                try await runStep(script.steps[index], index: index, jobID: jobID)
            }
            if ownsRecording {
                let result = try await model.recorder.stop()
                jobs[jobID]?.output = result.url.path
                jobs[jobID]?.results.append(["recording": result.json])
            }
            jobs[jobID]?.status = "completed"
            model.statusText = ownsRecording ? "A good take. Ready to share." : "Rehearsal complete"
        } catch {
            let cancelled = error is CancellationError && abortError == nil
            if ownsRecording && model.isRecording {
                // Finish on a fresh, uncancelled task so an interrupted take is still a playable MP4.
                let result = await Task { @MainActor in try? await self.model.recorder.stop() }.value
                jobs[jobID]?.output = result?.url.path
                if let result { jobs[jobID]?.results.append(["recording": result.json, "partial": true]) }
            }
            jobs[jobID]?.status = cancelled ? "cancelled" : "failed"
            if !cancelled {
                let failure = abortError ?? error
                jobs[jobID]?.error = failure.localizedDescription
                model.report(failure)
            } else { model.statusText = "Take stopped" }
        }
        jobs[jobID]?.finished = Date()
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

    private func runStep(_ step: Action, index: Int, jobID: String) async throws {
        model.currentStep = index
        model.statusText = step.displayLabel
        jobs[jobID]?.step = index + 1
        let started = CACurrentMediaTime()
        let value = try await perform(step)
        var result: [String: Any] = ["step": index + 1, "action": step.action.rawValue, "label": step.displayLabel,
                                     "duration": CACurrentMediaTime() - started]
        if let value { result["value"] = value }
        jobs[jobID]?.results.append(result)
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
            var lastX: Double = 0, lastY: Double = 0
            try await animate(duration: step.duration ?? 0.9, curve: step.easing) { p in
                let nextX = ((step.deltaX ?? 0) * p).rounded(), nextY = ((step.deltaY ?? 480) * p).rounded()
                try browser.scroll(at: point, deltaX: nextX - lastX, deltaY: nextY - lastY)
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
        case .zoom:
            let start = effects.camera
            let targetScale = step.scale ?? 1
            let focus: CGPoint
            if step.selector != nil || step.x != nil { focus = try await target(step) }
            else { focus = start.focus }
            if targetScale > 1, start.scale <= 1.001 {
                let image = try await browser.snapshot()
                browser.surface?.updateCamera(image: image)
            }
            try await animate(duration: step.duration ?? 1, curve: step.easing) { p in
                effects.camera = CameraState(scale: start.scale + (targetScale - start.scale) * p,
                    focus: CGPoint(x: start.focus.x + (focus.x - start.focus.x) * p, y: start.focus.y + (focus.y - start.focus.y) * p))
                browser.surface?.updateCamera()
            }
        case .caption:
            effects.showCaption(step)
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
            let data = try JSONSerialization.data(withJSONObject: [value], options: [.fragmentsAllowed])
            let actual = try JSONDecoder().decode([JSONValue].self, from: data)[0]
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
        while true {
            try Task.checkCancellation()
            let progress = min(1, (CACurrentMediaTime() - start) / duration)
            try update(Motion.ease(progress, curve: curve ?? "cinematic"))
            if progress >= 1 { break }
            try await Task.sleep(for: .milliseconds(12))
        }
    }
}
