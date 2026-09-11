import AppKit
import AVFoundation
import CoreVideo
import QuartzCore
import ShowtimeCore

struct RecordingResult {
    var url: URL
    var spec: RecordingSpec
    var frames: Int
    var captures: Int
    var averageRenderMilliseconds: Double
    var json: [String: Any] {
        ["output": url.path, "width": spec.width, "height": spec.height, "fps": spec.fps,
         "duration": Double(frames) / Double(spec.fps), "frames": frames, "capturedFrames": captures,
         "effectiveCaptureFPS": Double(captures * spec.fps) / Double(max(1, frames)),
         "duplicatedFrames": max(0, frames - captures), "averageRenderMilliseconds": averageRenderMilliseconds,
         "codec": "h264", "audio": false]
    }
}

@MainActor
final class MovieRecorder {
    // The worker finishes writing before ownership returns to the main actor.
    // No caller may access this buffer while the worker is drawing into it.
    private struct RenderedPixels: @unchecked Sendable {
        let buffer: CVPixelBuffer
    }

    unowned let model: StudioModel
    private(set) var spec = RecordingSpec()
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL?
    private var workingURL: URL?
    private var startTime: Double = 0
    private var frameCount = 0
    private var captureCount = 0
    private var previousBuffer: CVPixelBuffer?
    private var consuming = false
    private var totalRenderTime: Double = 0
    var elapsed: Double { startTime == 0 ? 0 : CACurrentMediaTime() - startTime }

    init(model: StudioModel) { self.model = model }

    func start(_ spec: RecordingSpec) async throws {
        guard !model.isRecording, !model.isFinishing, !model.isPreparing, writer == nil else { throw ShowtimeError("A recording is already active.") }
        try spec.validate(canvas: model.canvas)
        guard model.browser.ready else { throw ShowtimeError("Load a webpage before recording.") }
        guard model.window?.isMiniaturized != true else { throw ShowtimeError("Restore the browser window before recording.") }
        if model.mode == .director { model.mode = .theater }
        model.isPreparing = true
        model.statusText = "Preparing your take"
        defer { model.isPreparing = false }
        model.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let image = try await model.browser.snapshot(pixelWidth: model.snapshotPixelWidth(for: spec))
        try Task.checkCancellation()
        let destination = try OutputFiles.newURL(path: spec.output, defaultFolder: model.exportFolder, ext: "mp4")
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".showtime-\(UUID().uuidString).partial.mp4")
        let writer = try AVAssetWriter(outputURL: staging, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: spec.width,
            AVVideoHeightKey: spec.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(Double(spec.width * spec.height * spec.fps) * 0.18),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: spec.fps * 2,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: spec.width,
            kCVPixelBufferHeightKey as String: spec.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])
        guard writer.canAdd(input) else { throw ShowtimeError("The H.264 encoder rejected these output settings.") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ShowtimeError("Could not start the movie writer.") }
        writer.startSession(atSourceTime: .zero)
        self.writer = writer; self.input = input; self.adaptor = adaptor
        self.spec = spec; outputURL = destination; workingURL = staging
        model.rememberRecordingSettings(spec)
        frameCount = 0; captureCount = 0; previousBuffer = nil; totalRenderTime = 0
        startTime = CACurrentMediaTime()
        model.overlay.startTimeline(at: startTime)
        model.isRecording = true
        model.elapsed = 0
        model.statusText = "Recording a new take"
        if !model.isPlaying {
            model.playbackMode = .record
            model.activity.recordingStarted()
        }
        do { try await consume(webImage: image, at: startTime) }
        catch { await fail(error); throw error }
    }

    func consume(webImage: CGImage, at time: Double, effects capturedEffects: SceneCompositor.Effects? = nil) async throws {
        guard model.isRecording, !consuming, time >= startTime else { return }
        consuming = true
        defer { consuming = false }
        guard elapsed < 3600 else { throw ShowtimeError("A take is limited to one hour. Finish this take and start another.") }
        let desiredFrame = Int(max(0, time - startTime) * Double(spec.fps))
        guard frameCount <= desiredFrame else { return }
        let renderingStarted = CACurrentMediaTime()
        let canvas = model.canvas
        var effects = capturedEffects ?? SceneCompositor.Effects(model.effects)
        if capturedEffects == nil { effects.overlayImage = try await model.overlay.snapshot(at: time, pixelWidth: spec.width) }
        let camera = effects.camera
        let overlayImage = effects.overlayImage
        let backdrop = try SceneCompositor.browserBackdrop(model: model, width: spec.width, height: spec.height)
        guard let pool = adaptor?.pixelBufferPool else { throw ShowtimeError("The video pixel buffer pool is unavailable.") }
        // Composite directly into the encoder buffer without blocking native input
        // or allocating and copying an intermediate full-resolution CGImage.
        let pixels = try await Task.detached(priority: .userInitiated) {
            try autoreleasepool {
                var buffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess, let buffer else {
                    throw ShowtimeError("Could not allocate a video frame.")
                }
                try Self.draw(in: buffer, canvas: canvas) { context in
                    SceneCompositor.drawContent(canvas: canvas, camera: camera, webImage: webImage,
                                                backdrop: backdrop, overlayImage: overlayImage, context: context)
                }
                return RenderedPixels(buffer: buffer)
            }
        }.value
        let buffer = pixels.buffer
        // AppKit cursor artwork and text stay on the main actor. Use the effects
        // captured with this frame, even if the next animation tick has run.
        try Self.draw(in: buffer, canvas: canvas) { context in
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            defer { NSGraphicsContext.restoreGraphicsState() }
            SceneCompositor.drawEffects(canvas: canvas, effects: effects, context: context, time: time)
        }
        totalRenderTime += CACurrentMediaTime() - renderingStarted
        while frameCount <= desiredFrame {
            try await append(frameCount == desiredFrame ? buffer : (previousBuffer ?? buffer))
        }
        previousBuffer = buffer
        captureCount += 1
    }

    private nonisolated static func draw(in buffer: CVPixelBuffer, canvas: CanvasSpec,
                                         body: (CGContext) throws -> Void) throws {
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
            throw ShowtimeError("Could not access the video frame.")
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            throw ShowtimeError("Could not create the video rendering context.")
        }
        context.translateBy(x: 0, y: Double(height))
        context.scaleBy(x: Double(width) / Double(canvas.width), y: -Double(height) / Double(canvas.height))
        try body(context)
    }

    private func append(_ buffer: CVPixelBuffer) async throws {
        guard let writer, let input, let adaptor else { throw ShowtimeError("Recording is not active.") }
        let deadline = CACurrentMediaTime() + 10
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? ShowtimeError("The video encoder stopped unexpectedly.") }
            guard CACurrentMediaTime() < deadline else { throw ShowtimeError("The video encoder stalled.") }
            try await Task.sleep(for: .milliseconds(3))
        }
        let time = CMTime(value: Int64(frameCount), timescale: CMTimeScale(spec.fps))
        guard adaptor.append(buffer, withPresentationTime: time) else { throw writer.error ?? ShowtimeError("Could not append a video frame.") }
        frameCount += 1
    }

    func stop() async throws -> RecordingResult {
        guard model.isRecording, let writer, let input, let outputURL, let workingURL else { throw ShowtimeError("No recording is active.") }
        model.isRecording = false
        model.isFinishing = true
        model.statusText = "Finishing your film"
        defer { model.isFinishing = false; cleanup() }
        do {
            while consuming { try await Task.sleep(for: .milliseconds(5)) }
            let lastFrame = Int(ceil(elapsed * Double(spec.fps)))
            if let previousBuffer {
                while frameCount < max(1, lastFrame) { try await append(previousBuffer) }
            }
            writer.endSession(atSourceTime: CMTime(value: Int64(frameCount), timescale: CMTimeScale(spec.fps)))
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? ShowtimeError("MP4 export did not complete.") }
            try FileManager.default.moveItem(at: workingURL, to: outputURL)
            let result = RecordingResult(url: outputURL, spec: spec, frames: frameCount, captures: captureCount,
                                         averageRenderMilliseconds: totalRenderTime * 1000 / Double(max(1, captureCount)))
            model.lastExportURL = outputURL
            model.completedTakes += 1
            model.elapsed = Double(frameCount) / Double(spec.fps)
            model.statusText = "Saved · \(outputURL.lastPathComponent)"
            model.toasts.show("Film saved", message: outputURL.lastPathComponent, exportURL: outputURL)
            if !model.isPlaying { model.activity.finish(.completed, output: outputURL.path) }
            return result
        } catch {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: workingURL)
            throw error
        }
    }

    func fail(_ error: Error) async {
        model.isRecording = false
        writer?.cancelWriting()
        if let workingURL { try? FileManager.default.removeItem(at: workingURL) }
        cleanup()
        model.report(error)
        if !model.isPlaying { model.activity.finish(.failed, output: nil) }
        if model.isPlaying { model.director.abort(error) }
    }

    private func cleanup() {
        writer = nil; input = nil; adaptor = nil; previousBuffer = nil
        outputURL = nil; workingURL = nil; startTime = 0
    }
}
