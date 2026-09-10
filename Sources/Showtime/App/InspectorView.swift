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
                HStack(spacing: 9) {
                    ForEach(["mist", "pearl", "midnight"], id: \.self) { style in
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
                                }.frame(height: 52)
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
                VStack(spacing: 9) {
                    infoRow("Inset", value: "\(Int(model.canvas.inset)) px")
                    Slider(value: Binding(get: { model.canvas.inset }, set: {
                        var canvas = model.canvas; canvas.inset = $0.rounded()
                        do { try model.applyCapture(canvas: canvas) }
                        catch { model.report(error) }
                    }), in: 0...model.canvas.maximumInset)
                        .controlSize(.small).disabled(model.isBusy).accessibilityLabel("Canvas inset")
                }
            }
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
            InspectorSection(title: "Device frame", symbol: "macbook.and.iphone") {
                frameChoice(.none)
                frameGroup("iPhone", devices: DeviceFrame.allCases.filter(\.isPhone))
                frameGroup("iPad", devices: DeviceFrame.allCases.filter(\.isTablet))
                frameGroup("Mac", devices: DeviceFrame.allCases.filter(\.isMacBook))
            }
            InspectorSection(title: "Presentation", symbol: "rectangle.inset.filled") {
                infoRow("Web viewport", value: "\(Int(model.canvas.pageWidth)) × \(Int(model.canvas.pageHeight))")
                Text(model.canvas.frame == .none
                     ? "A clean browser window, without a device frame."
                     : "The page fills the screen area on your Canvas. Frames define proportions; Export controls image detail.")
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
            }), in: 1...3).controlSize(.small).accessibilityLabel("Camera close-up")
            Button {
                effects.camera = CameraState(scale: 1, focus: CGPoint(x: model.canvas.pageWidth / 2, y: model.canvas.pageHeight / 2))
                model.browser.surface?.updateCamera()
            } label: {
                Label("Reset camera", systemImage: "arrow.uturn.backward").font(.system(size: 12, weight: .medium))
            }.buttonStyle(.plain).foregroundStyle(Theme.accent)
        }.disabled(model.isPlaying)
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
        let camera = effects.camera
        effects.pointer.point = CGPoint(x: (model.canvas.pageWidth / 2 - camera.focus.x) / camera.scale + camera.focus.x,
                                        y: (model.canvas.pageHeight / 2 - camera.focus.y) / camera.scale + camera.focus.y)
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
