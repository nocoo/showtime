import SwiftUI
import ShowtimeCore

struct CaptureControls: View {
    enum Section { case canvas, video }
    @ObservedObject var model: StudioModel
    let section: Section
    @State private var canvasWidth = ""
    @State private var canvasHeight = ""
    @State private var videoWidth = ""
    @State private var videoHeight = ""
    @State private var customCanvas = false
    @State private var customVideo = false

    private static let canvases: [(id: String, title: String, width: Int, height: Int)] = [
        ("fullhd", "Full HD · 1920 × 1080", 1920, 1080),
        ("wide", "Widescreen · 1440 × 810", 1440, 810),
        ("compact", "Compact · 1280 × 720", 1280, 720),
        ("desktop", "Desktop · 1440 × 900", 1440, 900),
        ("square", "Square · 1080 × 1080", 1080, 1080),
        ("portrait", "Portrait · 900 × 1600", 900, 1600),
    ]
    private var videoPresets: [(edge: Int, title: String, spec: RecordingSpec)] {
        [(1280, "HD"), (1920, "Full HD"), (2560, "QHD"), (3840, "4K")].compactMap { edge, name in
            guard let spec = try? model.recordingSettings.fitted(to: model.canvas, longEdge: edge),
                  abs(max(spec.width, spec.height) - edge) <= 8 else { return nil }
            return (edge, "\(name) · \(spec.width) × \(spec.height)", spec)
        }
    }
    private var canvasSelection: Binding<String> {
        Binding(get: {
            customCanvas ? "custom" : Self.canvases.first { $0.width == model.canvas.width && $0.height == model.canvas.height }?.id ?? "custom"
        }, set: { id in
            customCanvas = id == "custom"
            guard let preset = Self.canvases.first(where: { $0.id == id }) else { return }
            applyCanvas(width: preset.width, height: preset.height)
        })
    }
    private var videoSelection: Binding<Int> {
        Binding(get: {
            customVideo ? 0 : videoPresets.first { $0.spec.width == model.recordingSettings.width && $0.spec.height == model.recordingSettings.height }?.edge ?? 0
        }, set: { edge in
            customVideo = edge == 0
            guard let preset = videoPresets.first(where: { $0.edge == edge }) else { return }
            do { try model.applyCapture(video: preset.spec) }
            catch { model.report(error) }
        })
    }

    var body: some View {
        Group {
            if section == .canvas {
                InspectorSection(title: "Canvas size", symbol: "aspectratio") {
                    StudioMenu(title: "Canvas preset", selection: Self.canvases.first { $0.id == canvasSelection.wrappedValue }?.title ?? "Custom size",
                               options: Self.canvases.map { preset in (preset.title, { canvasSelection.wrappedValue = preset.id }) }
                               + [("Custom size", { canvasSelection.wrappedValue = "custom" })])
                    dimensions(width: $canvasWidth, height: $canvasHeight, prefix: "Canvas") {
                        guard let width = Int(canvasWidth), let height = Int(canvasHeight) else {
                            model.report(ShowtimeError("Enter whole numbers for canvas width and height.")); return
                        }
                        customCanvas = true
                        applyCanvas(width: width, height: height)
                    }
                    Text("The browser lays out at this size. Video follows the same aspect ratio.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            } else {
                InspectorSection(title: "Video export", symbol: "film") {
                    StudioMenu(title: "Video resolution", selection: videoPresets.first { $0.edge == videoSelection.wrappedValue }?.title ?? "Custom resolution",
                               options: videoPresets.map { preset in (preset.title, { videoSelection.wrappedValue = preset.edge }) }
                               + [("Custom resolution", { videoSelection.wrappedValue = 0 })])
                    dimensions(width: $videoWidth, height: $videoHeight, prefix: "Video") {
                        guard let width = Int(videoWidth), let height = Int(videoHeight) else {
                            model.report(ShowtimeError("Enter whole numbers for video width and height.")); return
                        }
                        var spec = model.recordingSettings
                        spec.width = width; spec.height = height
                        do { try model.applyCapture(video: spec); customVideo = true }
                        catch { model.report(error) }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frame rate").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                        StudioSegmentedPicker(title: "Frame rate", choices: [(24, "24 fps"), (30, "30 fps"), (60, "60 fps")], selection: Binding(get: { model.recordingSettings.fps }, set: { fps in
                            var spec = model.recordingSettings; spec.fps = fps
                            do { try model.applyCapture(video: spec) }
                            catch { model.report(error) }
                        }))
                    }
                    HStack {
                        Label("MP4 · H.264", systemImage: "checkmark.seal")
                        Spacer()
                        Button(action: model.revealExport) { Image(systemName: "folder") }
                            .buttonStyle(.plain).help("Open exports").accessibilityLabel("Open exports")
                    }.font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Text("Record the current webpage with the header button, or let AI Director compose and export a film.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            }
        }
        .font(.system(size: 13)).tint(Theme.accent)
        .disabled(model.isBusy)
        .onAppear { syncCanvas(); syncVideo() }
        .onChange(of: [model.canvas.width, model.canvas.height]) { syncCanvas() }
        .onChange(of: [model.recordingSettings.width, model.recordingSettings.height]) { syncVideo() }
    }

    private func dimensions(width: Binding<String>, height: Binding<String>, prefix: String, apply: @escaping () -> Void) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            dimensionField("Width", value: width, label: "\(prefix) width", apply: apply)
            Text("×").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.bottom, 12)
            dimensionField("Height", value: height, label: "\(prefix) height", apply: apply)
            Button(action: apply) {
                Image(systemName: "arrow.turn.down.left").font(.system(size: 13, weight: .medium)).frame(width: 12)
            }.buttonStyle(StudioButtonStyle()).help("Apply \(prefix.lowercased()) size · Return")
                .accessibilityLabel("Apply \(prefix.lowercased()) size")
        }
    }

    private func dimensionField(_ title: String, value: Binding<String>, label: String, apply: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 11)).foregroundStyle(Theme.muted)
            TextField(title, text: value).textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 11).frame(height: 38).frame(maxWidth: .infinity)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 0.75))
                .onSubmit(apply).accessibilityLabel(label)
        }
    }

    private func applyCanvas(width: Int, height: Int) {
        var spec = model.canvas; spec.width = width; spec.height = height
        spec.inset = min(spec.inset, max(0, min((Double(width) - 600) / 2, (Double(height) - 300 - CanvasSpec.chromeHeight) / 2)))
        do { try model.applyCapture(canvas: spec); customVideo = false }
        catch { model.report(error) }
    }
    private func syncCanvas() { canvasWidth = String(model.canvas.width); canvasHeight = String(model.canvas.height) }
    private func syncVideo() { videoWidth = String(model.recordingSettings.width); videoHeight = String(model.recordingSettings.height) }
}
