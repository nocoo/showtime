import AppKit
import SwiftUI
import ShowtimeCore

struct InspectorView: View {
    @ObservedObject var model: StudioModel
    @ObservedObject var effects: EffectsState
    @State private var captionText = "Make room for your best work."
    @State private var captionSubtitle = "A little less busywork. A lot more momentum."
    @State private var captionStyle = "glass"
    @State private var captionPosition = "bottom"
    @State private var contentWidth = ""

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                navigationItem("Canvas", symbol: "rectangle.inset.filled")
                navigationItem("Frame", symbol: "iphone.gen3")
                navigationItem("Cursor", symbol: "cursorarrow.rays")
                navigationItem("Text", symbol: "textformat")
                navigationItem("Export", symbol: "square.and.arrow.up")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch model.selectedInspector {
                    case "Frame": frameControls
                    case "Cursor": cursorControls
                    case "Text": textControls
                    case "Export": CaptureControls(model: model, section: .video)
                    default: canvasControls
                    }
                }.padding(.bottom, 2)
            }.scrollIndicators(.automatic)

        }
        .frame(maxHeight: .infinity).tint(Theme.accent)
        .onChange(of: effects.pointer.style) { model.saveCursorPreset() }
        .onChange(of: effects.pointer.size) { model.saveCursorPreset() }
        .onChange(of: effects.pointer.color) { model.saveCursorPreset() }
        .onChange(of: effects.pointer.clickEffect) { model.saveCursorPreset() }
        .onChange(of: effects.pointer.hotspot) { model.saveCursorPreset() }
        .onChange(of: effects.pointer.customImagePath) { model.saveCursorPreset() }
    }

    private func navigationItem(_ title: String, symbol: String) -> some View {
        let selected = model.selectedInspector == title
        return Button { model.selectedInspector = title } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 17, weight: .regular)).frame(width: 22)
                Text(title).font(.system(size: 14, weight: selected ? .semibold : .medium))
                Spacer()
                if selected { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
            }
            .foregroundStyle(selected ? Theme.accent : Theme.muted)
            .padding(.horizontal, 14).frame(height: 42)
            .background(selected ? Theme.panel : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Theme.line : .clear, lineWidth: 0.75))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var canvasControls: some View {
        Group {
            CaptureControls(model: model, section: .canvas)
            InspectorSection(title: "Backdrop", symbol: "photo.on.rectangle.angled") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 12) {
                    ForEach(CanvasSpec.backdrops, id: \.self) { style in
                        Button {
                            var canvas = model.canvas; canvas.backdrop = style
                            do { try model.applyCapture(canvas: canvas) }
                            catch { model.report(error) }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    FilmBackdrop(style: style).clipShape(RoundedRectangle(cornerRadius: 9))
                                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.85))
                                        .frame(width: 34, height: 23).shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                }.frame(height: 42)
                                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(model.canvas.backdrop == style ? Theme.accent : Theme.line,
                                                                                         lineWidth: model.canvas.backdrop == style ? 1.8 : 0.75))
                                Text(style.capitalized).font(.system(size: 12, weight: model.canvas.backdrop == style ? .semibold : .regular))
                                    .foregroundStyle(model.canvas.backdrop == style ? Theme.accent : Theme.muted)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).disabled(model.isBusy)
                            .accessibilityLabel("\(style.capitalized) backdrop")
                            .accessibilityAddTraits(model.canvas.backdrop == style ? [.isSelected] : [])
                    }
                }
                if model.canvas.contentWidth == nil {
                    VStack(spacing: 9) {
                        infoRow("Inset", value: "\(Int(model.canvas.inset)) px")
                        Slider(value: Binding(get: { model.canvas.inset }, set: {
                            var canvas = model.canvas; canvas.inset = $0.rounded()
                            do { try model.applyCapture(canvas: canvas) }
                            catch { model.report(error) }
                        }), in: 0...model.canvas.maximumInset)
                            .controlSize(.small).disabled(model.isBusy).accessibilityLabel("Canvas inset")
                    }
                } else {
                    Text("Spacing is set by Content width in Frame.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            }
            InspectorSection(title: "Soft glow", symbol: "sun.max") {
                inspectorToggle("Center glow", isOn: canvasBinding(\.glow))
                if model.canvas.glow {
                    VStack(spacing: 8) {
                        infoRow("Radius", value: "\(Int((model.canvas.glowRadius * 100).rounded()))%")
                        Slider(value: canvasBinding(\.glowRadius), in: 0.1...1.5, step: 0.05)
                            .controlSize(.small).accessibilityLabel("Glow radius")
                            .help("How far the soft edge fades beyond the center")
                    }
                    VStack(spacing: 8) {
                        infoRow("Core size", value: "\(Int((model.canvas.glowSize * 100).rounded()))%")
                        Slider(value: canvasBinding(\.glowSize), in: 0...1, step: 0.05)
                            .controlSize(.small).accessibilityLabel("Glow core size")
                            .help("Size of the bright center")
                    }
                    Text("A gentle light behind the frame, adapted to its appearance.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            }.disabled(model.isBusy)
            InspectorSection(title: "Browser identity", symbol: "globe") {
                labeledField("Display title", placeholder: "Use page title", text: $model.titleOverride)
                labeledField("Display address", placeholder: "Use real URL", text: $model.urlOverride)
                Text("Leave blank to show the real page details.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                if !model.titleOverride.isEmpty || !model.urlOverride.isEmpty {
                    Button { model.titleOverride = ""; model.urlOverride = "" } label: {
                        Label("Reset to page details", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .medium))
                    }.foregroundStyle(Theme.accent).buttonStyle(.plain).disabled(model.isBusy)
                }
            }
            cameraControls
        }
    }

    private var frameControls: some View {
        Group {
            InspectorSection(title: "Content width", symbol: "arrow.left.and.right") {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("Auto", text: $contentWidth)
                            .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                            .onSubmit(applyContentWidth).accessibilityLabel("Content width")
                            .accessibilityHint("Screen width in Canvas pixels. Leave blank for Auto.")
                        Text("px").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 11).frame(height: 38)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 0.75))
                    Button(action: applyContentWidth) {
                        Image(systemName: "arrow.turn.down.left").font(.system(size: 13, weight: .medium)).frame(width: 12)
                    }.buttonStyle(StudioButtonStyle()).help("Apply content width · Return")
                        .accessibilityLabel("Apply content width")
                    Button("Auto") { contentWidth = ""; applyContentWidth() }
                        .buttonStyle(StudioButtonStyle()).help("Fit the frame automatically using Canvas inset")
                        .accessibilityLabel("Automatic content width")
                }
                Text("Up to \(model.canvas.maximumContentWidth) px. Leave blank for Auto.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
                infoRow("Web viewport", value: "\(Int(model.canvas.pageWidth)) × \(Int(model.canvas.pageHeight))")
                Text("Screen width, excluding the frame. Height follows the device; None uses the Canvas ratio. The frame stays centered.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
            }
            InspectorSection(title: "Device frame", symbol: "macbook.and.iphone") {
                frameChoice(.none)
                frameGroup("iPhone", devices: DeviceFrame.allCases.filter(\.isPhone))
                frameGroup("iPad", devices: DeviceFrame.allCases.filter(\.isTablet))
                frameGroup("Mac", devices: DeviceFrame.allCases.filter(\.isMacBook))
            }
            InspectorSection(title: "Presentation", symbol: "rectangle.inset.filled") {
                Text(model.canvas.frame == .none
                     ? "A centered browser window, without a device frame."
                     : "The page fills the screen at your content width. Export controls image detail.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.canvas.frame == .none ? "Browser title bar" : "Frame appearance")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                    StudioSegmentedPicker(title: "Frame appearance", choices: [("light", "Light"), ("dark", "Dark")], selection: Binding(get: { model.canvas.browserTheme }, set: { theme in
                        var canvas = model.canvas; canvas.browserTheme = theme
                        do { try model.applyCapture(canvas: canvas) }
                        catch { model.report(error) }
                    }))
                    if model.canvas.frame != .none {
                        Text(model.canvas.frame == .macbookNeo
                             ? "Light uses silver; Dark uses indigo."
                             : "Light uses silver; Dark uses space black.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }
                if !model.canvas.frame.showsBrowserChrome {
                    Text("This frame shows your page without the desktop title bar.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3)
                }
            }
        }.disabled(model.isBusy)
            .onAppear(perform: syncContentWidth)
            .onChange(of: model.canvas.contentWidth) { syncContentWidth() }
    }

    private func applyContentWidth() {
        let value = contentWidth.trimmingCharacters(in: .whitespacesAndNewlines)
        var canvas = model.canvas
        if value.isEmpty || value.lowercased() == "auto" {
            canvas.contentWidth = nil
        } else {
            guard let width = Int(value) else {
                model.report(ShowtimeError("Enter a whole number for content width, or use Auto.")); return
            }
            canvas.contentWidth = width
        }
        do { try model.applyCapture(canvas: canvas); syncContentWidth() }
        catch { model.report(error) }
    }

    private func syncContentWidth() {
        contentWidth = model.canvas.contentWidth.map(String.init) ?? ""
    }

    private func frameGroup(_ title: String, devices: [DeviceFrame]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                .padding(.top, 4).padding(.leading, 2)
            ForEach(devices, id: \.self) { frameChoice($0) }
        }
    }

    private func frameChoice(_ frame: DeviceFrame) -> some View {
        let selected = model.canvas.frame == frame
        return Button {
            var canvas = model.canvas; canvas.frame = frame
            canvas.inset = min(canvas.inset, canvas.maximumInset)
            do { try model.applyCapture(canvas: canvas) }
            catch { model.report(error) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: frame.symbol).font(.system(size: 23, weight: .light))
                    .frame(width: 30).foregroundStyle(selected ? Theme.accent : Theme.muted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(frame.title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(frame == .none ? "Browser only · Default"
                         : frame == .macbookNeo ? "2026 · 13″ Liquid Retina"
                         : frame == .macbookPro ? "2026 · 16.2″ Liquid Retina XDR"
                         : String(format: "%.2f:1 screen", frame.referenceScreenSize.width / frame.referenceScreenSize.height))
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "smallcircle.filled.circle" : "circle")
                    .font(.system(size: 13, weight: .regular)).foregroundStyle(selected ? Theme.accent : Theme.line)
            }
            .padding(.horizontal, 10).frame(height: 55)
            .background(selected ? Theme.accent.opacity(0.06) : Theme.field, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Theme.accent.opacity(0.5) : Theme.line, lineWidth: 0.75))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel("\(frame.title) frame")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var cameraControls: some View {
        InspectorSection(title: "Camera", symbol: "viewfinder") {
            HStack {
                Text("Close-up").font(.system(size: 13))
                Spacer()
                Text(String(format: "%.2f×", effects.camera.scale))
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.accent)
            }
            Slider(value: Binding(get: { effects.camera.scale }, set: {
                effects.camera.scale = $0; model.browser.surface?.updateCamera()
            }), in: 0.25...4).controlSize(.small).accessibilityLabel("Camera close-up")
            HStack {
                Text("Offset").font(.system(size: 13))
                Spacer()
                Button("Center") {
                    effects.camera.offset = .zero; model.browser.surface?.updateCamera()
                }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.accent)
                    .disabled(effects.camera.offset == .zero).accessibilityLabel("Center camera offset")
            }
            CameraOffsetPad(offset: Binding(get: { effects.camera.offset }, set: {
                effects.camera.offset = $0; model.browser.surface?.updateCamera()
            }), range: CGSize(width: model.canvas.pageWidth / 2, height: model.canvas.pageHeight / 2))
            HStack {
                Text(String(format: "X %+.0f", effects.camera.offset.x))
                Spacer()
                Text(String(format: "Y %+.0f px", effects.camera.offset.y))
            }.font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
            Button {
                effects.camera = CameraState(scale: 1, focus: CGPoint(x: model.canvas.pageWidth / 2, y: model.canvas.pageHeight / 2))
                model.browser.surface?.updateCamera()
            } label: {
                Label("Reset camera", systemImage: "arrow.uturn.backward").font(.system(size: 12, weight: .medium))
            }.buttonStyle(.plain).foregroundStyle(Theme.accent).disabled(effects.camera.isIdentity)
        }.disabled(model.isPlaying || model.isPreparing || model.isFinishing)
    }

    private func canvasBinding<Value>(_ keyPath: WritableKeyPath<CanvasSpec, Value>) -> Binding<Value> {
        Binding(get: { model.canvas[keyPath: keyPath] }, set: { value in
            var canvas = model.canvas; canvas[keyPath: keyPath] = value
            do { try model.applyCapture(canvas: canvas) }
            catch { model.report(error) }
        })
    }

    private var cursorControls: some View {
        Group {
            InspectorSection(title: "Cursor style", symbol: "cursorarrow") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                    cursorCard("arrow", title: "System arrow")
                    cursorCard("hand", title: "System hand")
                    cursorCard("ring", title: "Focus ring")
                    cursorCard("dot", title: "Soft dot")
                    cursorCard("spotlight", title: "Spotlight")
                    cursorCard("custom", title: "Your image")
                }
                Text(["arrow", "hand"].contains(effects.pointer.style)
                     ? "Matches your Mac’s cursor, including its shape and colors."
                     : "Guide the eye with a clear, gentle point of focus.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            InspectorSection(title: "Appearance", symbol: "paintbrush.pointed") {
                inspectorToggle("Show cursor", isOn: $effects.pointer.visible)
                VStack(spacing: 9) {
                    infoRow("Size", value: "\(Int(effects.pointer.size)) px")
                    Slider(value: $effects.pointer.size, in: 12...64).controlSize(.small).accessibilityLabel("Cursor size")
                }
                HStack(spacing: 10) {
                    Text("Accent").font(.system(size: 13)); Spacer()
                    ForEach([Theme.accentHex, "#3B82F6", "#14B8A6", "#F59E0B"], id: \.self) { hex in
                        Button { effects.pointer.color = hex } label: {
                            Circle().fill(Color(nsColor: SceneCompositor.color(hex))).frame(width: 20, height: 20)
                                .overlay(Circle().strokeBorder(.white, lineWidth: effects.pointer.color == hex ? 3 : 0))
                                .overlay(Circle().strokeBorder(Color(nsColor: SceneCompositor.color(hex)), lineWidth: 1))
                        }.buttonStyle(.plain).help(hex).accessibilityLabel("Accent \(hex)")
                            .accessibilityAddTraits(effects.pointer.color == hex ? [.isSelected] : [])
                    }
                }
                inspectorToggle("Click ripple", isOn: $effects.pointer.clickEffect)
                Button { placePointer(); effects.click(at: effects.pointer.point) } label: {
                    Label("Preview click", systemImage: "cursorarrow.click")
                        .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity).frame(height: 36)
                        .foregroundStyle(Theme.accent).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
            }
            if effects.pointer.style == "custom" {
                InspectorSection(title: "Custom image", symbol: "photo") {
                    Button(action: chooseCustomCursor) {
                        Label("Choose another image…", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 12))
                    }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Text("Click point").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                    StudioSegmentedPicker(title: "Click point", choices: [("tip", "Top left"), ("center", "Center")], selection: Binding(get: { effects.pointer.hotspot.x == 0.5 ? "center" : "tip" }, set: {
                        effects.pointer.hotspot = $0 == "center" ? CGPoint(x: 0.5, y: 0.5) : .zero
                    }))
                    Text("Transparent PNG works best.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
        }.disabled(model.isPlaying || model.isPreparing)
    }

    private func cursorCard(_ style: String, title: String) -> some View {
        let selected = effects.pointer.style == style
        var preview = effects.pointer
        preview.style = style; preview.size = style == "spotlight" ? 20 : 32; preview.pressed = false
        return Button {
            if style == "custom", effects.pointer.customImage == nil { chooseCustomCursor(); return }
            effects.pointer.style = style
            effects.pointer.size = ["arrow", "hand"].contains(style) ? 36 : 28
            placePointer()
        } label: {
            VStack(spacing: 7) {
                if style == "custom" && effects.pointer.customImage == nil {
                    Image(systemName: "photo.badge.plus").font(.system(size: 20, weight: .light))
                        .foregroundStyle(Theme.muted).frame(height: 42)
                } else { CursorPreview(pointer: preview).frame(height: 42) }
                Text(title).font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.ink.opacity(0.85))
            }.frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(selected ? Theme.accent.opacity(0.05) : Theme.field, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? Theme.accent.opacity(0.65) : Theme.line,
                                                                                      lineWidth: selected ? 1.5 : 0.75))
                .overlay(alignment: .topTrailing) {
                    if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.accent).padding(7) }
                }
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func placePointer() {
        effects.pointer.point = CGPoint(x: model.canvas.pageWidth / 2, y: model.canvas.pageHeight / 2)
            .applying(effects.camera.transform.inverted())
        effects.pointer.visible = true
    }

    private func chooseCustomCursor() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .tiff, .jpeg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var action = Action(.cursor); action.style = "custom"; action.image = url.path; action.visible = true
        Task {
            do { _ = try await model.director.perform(action); placePointer() }
            catch { model.report(error) }
        }
    }

    private var textControls: some View {
        Group {
            InspectorSection(title: "On-screen text", symbol: "text.bubble") {
                labeledField("Headline", placeholder: "Your next big idea", text: $captionText)
                labeledField("Supporting line", placeholder: "Optional", text: $captionSubtitle)
            }
            InspectorSection(title: "Presentation", symbol: "rectangle.3.group.bubble") {
                Text("Style").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                StudioSegmentedPicker(title: "Caption style", choices: [("glass", "Glass"), ("minimal", "Minimal"), ("title", "Title")], selection: $captionStyle)
                Text("Position").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                StudioSegmentedPicker(title: "Caption position", choices: [("bottom", "Bottom"), ("center", "Center"), ("top", "Top")], selection: $captionPosition)
                Button {
                    var action = Action(.caption); action.text = captionText; action.subtitle = captionSubtitle
                    action.style = captionStyle; action.position = captionPosition; action.duration = 4
                    effects.showCaption(action)
                } label: {
                    Label("Preview text", systemImage: "play.rectangle")
                        .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity).frame(height: 38)
                        .foregroundStyle(Theme.accent).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
                Button { effects.captionTask?.cancel(); effects.caption = nil } label: {
                    Label("Clear text", systemImage: "xmark.circle").font(.system(size: 12))
                }.buttonStyle(.plain).foregroundStyle(Theme.muted)
                Text("Text eases into the frame and fades away. Preview lasts four seconds.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
            }
        }.disabled(model.isPlaying)
    }


    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 13, weight: .medium))
            TextField(placeholder, text: text).font(.system(size: 14)).textFieldStyle(.plain)
                .padding(.horizontal, 11).padding(.vertical, 11)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line, lineWidth: 0.75))
                .disabled(model.isBusy).accessibilityLabel(label)
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted); Spacer()
            Text(value).foregroundStyle(Theme.ink.opacity(0.85))
        }.font(.system(size: 13))
    }

    private func inspectorToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 13)); Spacer()
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

private struct CameraOffsetPad: View {
    @Binding var offset: CGPoint
    let range: CGSize
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        GeometryReader { geometry in
            let half = CGSize(width: max(1, geometry.size.width / 2 - 14), height: max(1, geometry.size.height / 2 - 14))
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let point = CGPoint(x: center.x + min(1, max(-1, offset.x / range.width)) * half.width,
                                y: center.y + min(1, max(-1, offset.y / range.height)) * half.height)
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(Theme.field)
                Path { path in
                    path.move(to: CGPoint(x: 14, y: center.y)); path.addLine(to: CGPoint(x: geometry.size.width - 14, y: center.y))
                    path.move(to: CGPoint(x: center.x, y: 14)); path.addLine(to: CGPoint(x: center.x, y: geometry.size.height - 14))
                }.stroke(Theme.line, style: StrokeStyle(lineWidth: 0.75, dash: [3, 4]))
                Circle().strokeBorder(Theme.muted.opacity(0.3), lineWidth: 1).frame(width: 6, height: 6).position(center)
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 26, height: 26).position(point)
                Circle().fill(Theme.accent).frame(width: 9, height: 9).position(point)
            }
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(focused ? Theme.accent.opacity(0.65) : Theme.line, lineWidth: 0.75))
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard enabled else { return }
                focused = true
                offset = CGPoint(x: (min(1, max(-1, (value.location.x - center.x) / half.width)) * range.width).rounded(),
                                 y: (min(1, max(-1, (value.location.y - center.y) / half.height)) * range.height).rounded())
            })
        }
        .frame(height: 108).opacity(enabled ? 1 : 0.45).focusable(enabled).focused($focused).focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .left: move(x: -10)
            case .right: move(x: 10)
            case .up: move(y: -10)
            case .down: move(y: 10)
            @unknown default: break
            }
        }
        .onKeyPress(.space) {
            guard enabled else { return .ignored }
            offset = .zero; return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera offset")
        .accessibilityValue(String(format: "Horizontal %+.0f pixels, vertical %+.0f pixels", offset.x, offset.y))
        .accessibilityHint("Click or drag to move. Arrow keys adjust by 10 pixels. Space centers the camera.")
        .accessibilityAction(named: Text("Move left")) { move(x: -10) }
        .accessibilityAction(named: Text("Move right")) { move(x: 10) }
        .accessibilityAction(named: Text("Move up")) { move(y: -10) }
        .accessibilityAction(named: Text("Move down")) { move(y: 10) }
        .accessibilityAction(named: Text("Center offset")) { if enabled { offset = .zero } }
    }

    private func move(x: Double = 0, y: Double = 0) {
        guard enabled else { return }
        offset = CGPoint(x: min(range.width, max(-range.width, offset.x + x)),
                         y: min(range.height, max(-range.height, offset.y + y)))
    }
}
