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

    private static let canvases: [(title: String, width: Int, height: Int)] = [
        ("4K · 3840 × 2160", 3840, 2160),
        ("Full HD · 1920 × 1080", 1920, 1080),
        ("Widescreen · 1440 × 810", 1440, 810),
        ("Compact · 1280 × 720", 1280, 720),
        ("Desktop · 1440 × 900", 1440, 900),
        ("Square · 1080 × 1080", 1080, 1080),
        ("Portrait · 900 × 1600", 900, 1600),
    ]
    private var videoPresets: [(edge: Int, title: String, spec: RecordingSpec)] {
        [(1280, "HD"), (1920, "Full HD"), (2560, "QHD"), (3840, "4K")].compactMap { edge, name in
            guard let spec = try? model.recordingSettings.fitted(to: model.canvas, longEdge: edge),
                  abs(max(spec.width, spec.height) - edge) <= 8 else { return nil }
            return (edge, "\(name) · \(spec.width) × \(spec.height)", spec)
        }
    }

    var body: some View {
        Group {
            if section == .canvas {
                let selected = Self.canvases.first { $0.width == model.canvas.width && $0.height == model.canvas.height }
                InspectorSection(title: "Canvas size", symbol: "aspectratio") {
                    StudioMenu(title: "Canvas preset", selection: customCanvas ? "Custom size" : selected?.title ?? "Custom size",
                               options: Self.canvases.map { preset in
                                   (preset.title, { customCanvas = false; applyCanvas(width: preset.width, height: preset.height) })
                               } + [("Custom size", { customCanvas = true })])
                    dimensions(width: $canvasWidth, height: $canvasHeight, prefix: "Canvas") {
                        guard let width = Int(canvasWidth), let height = Int(canvasHeight) else {
                            model.report(ShowtimeError("Enter whole numbers for canvas width and height.")); return
                        }
                        customCanvas = true
                        applyCanvas(width: width, height: height)
                    }
                    Text("The final composition size, up to 3840 × 2160. Set Content width in Frame to control spacing; Export controls image detail and video resolution.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            } else {
                let presets = videoPresets
                let selected = presets.first { $0.spec.width == model.recordingSettings.width && $0.spec.height == model.recordingSettings.height }
                InspectorSection(title: "Video export", symbol: "film") {
                    StudioMenu(title: "Video resolution", selection: customVideo ? "Custom resolution" : selected?.title ?? "Custom resolution",
                               options: presets.map { preset in (preset.title, {
                                   customVideo = false
                                   guard let current = videoPresets.first(where: { $0.edge == preset.edge }) else { return }
                                   do { try model.applyCapture(video: current.spec) }
                                   catch { model.report(error) }
                               }) } + [("Custom resolution", { customVideo = true })])
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
        spec.inset = min(spec.inset, spec.maximumInset)
        do { try model.applyCapture(canvas: spec); customVideo = false }
        catch { model.report(error) }
    }
    private func syncCanvas() { canvasWidth = String(model.canvas.width); canvasHeight = String(model.canvas.height) }
    private func syncVideo() { videoWidth = String(model.recordingSettings.width); videoHeight = String(model.recordingSettings.height) }
}
