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
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14)).foregroundStyle(Theme.muted)
                Text("Director").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { model.showInspector = false } label: {
                    Image(systemName: "sidebar.right").font(.system(size: 14)).foregroundStyle(Theme.muted)
                }.buttonStyle(.plain).help("Hide director").accessibilityLabel("Hide director")
            }.padding(.horizontal, 22).frame(height: 54)
            HStack(spacing: 3) {
                ForEach(["Canvas", "Cursor", "Text"], id: \.self) { title in
                    Button { model.selectedInspector = title } label: {
                        Text(title).font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 32)
                            .foregroundStyle(model.selectedInspector == title ? Theme.ink : Theme.muted)
                            .background(model.selectedInspector == title ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                            .shadow(color: .black.opacity(model.selectedInspector == title ? 0.04 : 0), radius: 2, y: 1)
                    }.buttonStyle(.plain)
                }
            }.padding(3).background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                .padding(.horizontal, 20).padding(.bottom, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    switch model.selectedInspector {
                    case "Cursor": cursorControls
                    case "Text": textControls
                    default: canvasControls
                    }
                }.padding(.horizontal, 22).padding(.bottom, 24)
            }.scrollIndicators(.automatic)
            connectionCard.padding(18)
        }.background(.white.opacity(0.86)).tint(Theme.accent)
            .onChange(of: effects.pointer.style) { model.saveCursorPreset() }
            .onChange(of: effects.pointer.size) { model.saveCursorPreset() }
            .onChange(of: effects.pointer.color) { model.saveCursorPreset() }
            .onChange(of: effects.pointer.clickEffect) { model.saveCursorPreset() }
            .onChange(of: effects.pointer.hotspot) { model.saveCursorPreset() }
            .onChange(of: effects.pointer.customImagePath) { model.saveCursorPreset() }
    }

    private var canvasControls: some View {
        Group {
            VStack(alignment: .leading, spacing: 15) {
                section("BROWSER IDENTITY")
                labeledField("Display title", placeholder: "Use page title", text: $model.titleOverride)
                labeledField("Display address", placeholder: "Use real URL", text: $model.urlOverride)
                Text("Leave blank to show the real page details.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                if !model.titleOverride.isEmpty || !model.urlOverride.isEmpty {
                    Button("Reset to page details") { model.titleOverride = ""; model.urlOverride = "" }
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent).buttonStyle(.plain).disabled(model.isBusy)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 15) {
                section("FRAME & BACKDROP")
                HStack(spacing: 9) {
                    ForEach(["mist", "pearl", "midnight"], id: \.self) { style in
                        Button {
                            model.canvas.backdrop = style
                            model.currentScript?.canvas = model.canvas
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    FilmBackdrop(style: style).clipShape(RoundedRectangle(cornerRadius: 8))
                                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.8))
                                        .frame(width: 34, height: 23).shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                }.frame(height: 51)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.canvas.backdrop == style ? Theme.accent : Theme.line, lineWidth: model.canvas.backdrop == style ? 1.8 : 0.7))
                                Text(style.capitalized).font(.system(size: 11, weight: model.canvas.backdrop == style ? .semibold : .regular))
                                    .foregroundStyle(model.canvas.backdrop == style ? Theme.accent : Theme.muted)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).disabled(model.isBusy)
                    }
                }
                infoRow("Canvas", value: "\(model.canvas.width) × \(model.canvas.height)")
                infoRow("Inset", value: "\(Int(model.canvas.inset)) px")
                Slider(value: Binding(get: { model.canvas.inset }, set: {
                    model.canvas.inset = $0.rounded(); model.currentScript?.canvas = model.canvas
                }), in: 0...100).tint(Theme.accent).controlSize(.small).disabled(model.isBusy)
            }
            Divider()
            cameraControls
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                section("EXPORT")
                infoRow("Format", value: "MP4 · H.264")
                infoRow("Resolution", value: "\(model.currentScript?.recording?.width ?? 1920) × \(model.currentScript?.recording?.height ?? 1080)")
                infoRow("Frame rate", value: "\(model.currentScript?.recording?.fps ?? 30) fps")
                Button { model.toggleRecording() } label: {
                    Label(model.isRecording && !model.isPlaying ? "Finish recording" : "Record manually", systemImage: "record.circle")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.accent)
                }.buttonStyle(.plain).disabled(model.isPlaying || model.isFinishing || model.isPreparing)
                Button(action: model.revealExport) {
                    Label("Open exports", systemImage: "folder").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }.buttonStyle(.plain)
            }
        }
    }

    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("CAMERA")
            HStack {
                Text("Close-up").font(.system(size: 13))
                Spacer()
                Text(String(format: "%.2f×", effects.camera.scale)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.accent)
            }
            Slider(value: Binding(get: { effects.camera.scale }, set: {
                effects.camera.scale = $0; model.browser.surface?.updateCamera()
            }), in: 1...3).tint(Theme.accent).controlSize(.small)
            Button("Reset camera") {
                effects.camera = CameraState(scale: 1, focus: CGPoint(x: model.canvas.pageWidth / 2, y: model.canvas.pageHeight / 2))
                model.browser.surface?.updateCamera()
            }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.accent)
        }.disabled(model.isPlaying)
    }

    private var cursorControls: some View {
        Group {
            VStack(alignment: .leading, spacing: 15) {
                section("CURSOR STYLE")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
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
            Divider()
            VStack(alignment: .leading, spacing: 17) {
                section("APPEARANCE")
                inspectorToggle("Show cursor", isOn: $effects.pointer.visible)
                HStack {
                    Text("Size").font(.system(size: 13)); Spacer()
                    Text("\(Int(effects.pointer.size)) px").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted)
                }
                Slider(value: $effects.pointer.size, in: 12...64).tint(Theme.accent).controlSize(.small)
                HStack(spacing: 10) {
                    Text("Accent").font(.system(size: 13)); Spacer()
                    ForEach([Theme.accentHex, "#3B82F6", "#14B8A6", "#F59E0B"], id: \.self) { hex in
                        Button { effects.pointer.color = hex } label: {
                            Circle().fill(Color(nsColor: SceneCompositor.color(hex))).frame(width: 20, height: 20)
                                .overlay(Circle().strokeBorder(.white, lineWidth: effects.pointer.color == hex ? 3 : 0))
                                .overlay(Circle().strokeBorder(Color(nsColor: SceneCompositor.color(hex)), lineWidth: 1))
                        }.buttonStyle(.plain).help(hex).accessibilityLabel("Accent \(hex)")
                    }
                }
                inspectorToggle("Click ripple", isOn: $effects.pointer.clickEffect)
                Button {
                    placePointer(); effects.click(at: effects.pointer.point)
                } label: {
                    Label("Preview click", systemImage: "cursorarrow.click")
                        .font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity).frame(height: 36)
                        .foregroundStyle(Theme.accent).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
            if effects.pointer.style == "custom" {
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    section("CUSTOM IMAGE")
                    Button("Choose another image…", action: chooseCustomCursor)
                        .font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(Theme.accent)
                    Picker("Click point", selection: Binding(get: { effects.pointer.hotspot.x == 0.5 ? "center" : "tip" }, set: {
                        effects.pointer.hotspot = $0 == "center" ? CGPoint(x: 0.5, y: 0.5) : .zero
                    })) { Text("Top left").tag("tip"); Text("Center").tag("center") }
                        .font(.system(size: 12)).controlSize(.small)
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
            VStack(spacing: 5) {
                if style == "custom" && effects.pointer.customImage == nil {
                    Image(systemName: "plus").font(.system(size: 20, weight: .light)).foregroundStyle(Theme.muted).frame(height: 44)
                } else { CursorPreview(pointer: preview).frame(height: 44) }
                Text(title).font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.accent : Theme.ink.opacity(0.8))
            }.frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(selected ? Theme.accent.opacity(0.045) : Theme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Theme.accent.opacity(0.8) : Theme.line, lineWidth: selected ? 1.5 : 0.7))
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
        VStack(alignment: .leading, spacing: 20) {
            section("ON-SCREEN TEXT")
            labeledField("Headline", placeholder: "Your next big idea", text: $captionText)
            labeledField("Supporting line", placeholder: "Optional", text: $captionSubtitle)
            Picker("Style", selection: $captionStyle) {
                Text("Glass").tag("glass"); Text("Minimal").tag("minimal"); Text("Title").tag("title")
            }.font(.system(size: 13)).controlSize(.small)
            Picker("Position", selection: $captionPosition) {
                Text("Bottom").tag("bottom"); Text("Center").tag("center"); Text("Top").tag("top")
            }.font(.system(size: 13)).controlSize(.small)
            Button {
                var action = Action(.caption); action.text = captionText; action.subtitle = captionSubtitle
                action.style = captionStyle; action.position = captionPosition; action.duration = 4
                effects.showCaption(action)
            } label: {
                Label("Preview text", systemImage: "text.bubble").font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity).frame(height: 37).foregroundStyle(Theme.accent)
                    .background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
            Button("Clear text") { effects.captionTask?.cancel(); effects.caption = nil }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text("Text eases into the frame and fades away. Preview lasts four seconds.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
        }.disabled(model.isPlaying)
    }

    private var connectionCard: some View {
        Button { model.showConnection = true } label: {
            HStack(spacing: 11) {
                Image(systemName: "terminal").font(.system(size: 18)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect your agent").font(.system(size: 13, weight: .semibold))
                    Text("Direct your next take.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.system(size: 12)).foregroundStyle(Theme.accent)
            }.padding(14).background(Theme.accent.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent.opacity(0.09)))
        }.buttonStyle(.plain)
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.muted)
    }

    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 13, weight: .medium))
            TextField(placeholder, text: text).font(.system(size: 13)).textFieldStyle(.plain)
                .padding(.horizontal, 11).padding(.vertical, 10).background(Theme.surface, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.line, lineWidth: 0.7)).disabled(model.isBusy)
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted); Spacer()
            Text(value).foregroundStyle(Theme.ink.opacity(0.8))
        }.font(.system(size: 12))
    }

    private func inspectorToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 13)); Spacer()
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

struct ConnectionView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    private var mcpConfig: String {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Tools/showtime_mcp.py").path ?? ""
        let fallback = FileManager.default.currentDirectoryPath + "/scripts/showtime_mcp.py"
        let path = FileManager.default.fileExists(atPath: bundled) ? bundled : fallback
        let object: [String: Any] = ["mcpServers": ["showtime": ["command": "python3", "args": [path]]]]
        return String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "terminal.fill").font(.system(size: 25)).foregroundStyle(Theme.accent)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Give your agent the director’s chair.").font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                Text("Use the MCP bridge, the CLI, or the local HTTP API.").font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            HStack {
                Circle().fill(model.agentReady ? Color.green : Color.orange).frame(width: 7, height: 7)
                Text("http://127.0.0.1:\(model.agentPort)").font(.system(size: 14, design: .monospaced))
                Spacer()
                Text("LOCAL ONLY").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
            }.padding(13).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            Text(mcpConfig).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                .padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            Button(copied ? "Copied" : "Copy MCP configuration") {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(mcpConfig, forType: .string); copied = true
            }.buttonStyle(.borderedProminent).tint(Theme.accent)
            Text("The bridge reads the session token from ~/Library/Application Support/Showtime/connection.json. No credentials need to be pasted into your agent configuration.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(3)
        }.padding(30).frame(width: 590).foregroundStyle(Theme.ink).background(.white)
    }
}
