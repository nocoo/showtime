import AppKit
import SwiftUI
import ShowtimeCore

struct StudioView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sidebarVisible: Bool { model.showInspector && model.mode == .studio }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                workspace
                    .opacity(model.mode == .director ? 0 : 1)
                    .allowsHitTesting(model.mode != .director)
                    .accessibilityHidden(model.mode == .director)
                DirectorGuideView(model: model)
                    .opacity(model.mode == .director ? 1 : 0)
                    .allowsHitTesting(model.mode == .director)
                    .accessibilityHidden(model.mode != .director)
            }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: sidebarVisible)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: model.mode)
            statusBar
        }
        .background(Theme.surface)
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .toolbarBackground(Theme.surface, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) { brand }.hideSharedBackground()
            ToolbarItem(placement: .principal) { modePicker }.hideSharedBackground()
            ToolbarItem(placement: .primaryAction) { transport }.hideSharedBackground()
        }
        .overlay(alignment: .topTrailing) {
            StudioToastOverlay(center: model.toasts).padding(.trailing, 16).padding(.top, 12)
        }
    }

    private var workspace: some View {
        HStack(alignment: .top, spacing: 16) {
                if sidebarVisible {
                    InspectorView(model: model, effects: model.effects)
                        .frame(width: 280)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                VStack(spacing: 0) {
                    canvasArea.frame(maxHeight: .infinity)
                    Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 24)
                    if model.theaterMode {
                        DirectorActivityView(model: model, activity: model.activity)
                    } else {
                        StoryboardView(model: model)
                    }
                }
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line, lineWidth: 0.75))
        }
    }

    private var brand: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(nsImage: AppResources.brandMark)
                    .resizable().renderingMode(.original).interpolation(.high).scaledToFit()
                    .frame(width: 30, height: 30).accessibilityHidden(true)
                Text("showtime").font(.system(size: 18, weight: .semibold, design: .rounded)).tracking(-0.4)
            }
            .shadow(color: .black.opacity(model.appearance == .dark ? 0.24 : 0.10), radius: 1.2, x: 0, y: 1)
            .allowsHitTesting(false)
            Button {
                if model.mode != .studio { model.mode = .studio; model.showInspector = true }
                else { model.showInspector.toggle() }
            } label: {
                Image(systemName: "sidebar.left").font(.system(size: 16))
                    .foregroundStyle(sidebarVisible ? Theme.accent : Theme.muted)
            }.buttonStyle(StudioButtonStyle(treatment: .plain))
                .help(sidebarVisible ? "Hide sidebar" : "Show sidebar")
                .accessibilityLabel(sidebarVisible ? "Hide sidebar" : "Show sidebar")
        }
        .padding(.trailing, 12).frame(height: 38)
        .foregroundStyle(Theme.ink)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            modeButton("Studio", symbol: "rectangle.leftthird.inset.filled", selected: model.mode == .studio) {
                model.mode = .studio
            }
            modeButton("Theater", symbol: "rectangle.inset.filled", selected: model.theaterMode) {
                model.theaterMode = true
            }
            modeButton("AI Director", symbol: "sparkles", selected: model.mode == .director) {
                model.mode = .director
            }.disabled(model.isBusy)
        }
        .labelStyle(.titleAndIcon)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain).accessibilityLabel("Workspace mode")
    }

    private func modeButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Theme.accent : Theme.muted)
                .padding(.horizontal, 12).frame(height: 38)
                .overlay(alignment: .bottom) {
                    if selected { Capsule().fill(Theme.accent).frame(height: 2).padding(.horizontal, 12) }
                }
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var transport: some View {
        HStack(spacing: 8) {
            Button {
                model.appearance = model.appearance == .light ? .dark : .light
            } label: {
                Image(systemName: model.appearance == .light ? "moon" : "sun.max")
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            }.buttonStyle(StudioButtonStyle(treatment: .plain))
                .help("Switch to \(model.appearance == .light ? "dark" : "light") theme")
                .accessibilityLabel("Switch to \(model.appearance == .light ? "dark" : "light") theme")
            Button(action: model.revealExport) { Image(systemName: "folder") }
                .buttonStyle(StudioButtonStyle(treatment: .plain))
                .help("Show exports").accessibilityLabel("Show exports")
            Button {
                if model.isRehearsing { model.director.cancel() }
                else { model.playStoryboard(record: false) }
            } label: { Label(model.isRehearsing ? "Stop rehearsal" : "Rehearse", systemImage: model.isRehearsing ? "stop.fill" : "play") }
                .buttonStyle(StudioButtonStyle()).disabled(!model.isRehearsing && (model.isBusy || model.currentScript == nil))
                .help("Rehearse the storyboard · ⌘Return")
            Button(action: model.toggleRecording) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: recordingJob ? "stop.fill" : "record.circle")
                        .frame(width: 16, height: 16).accessibilityHidden(true)
                    Text(recordingTitle)
                }
                .font(.system(size: 14, weight: .semibold)).lineLimit(1)
                .fixedSize(horizontal: true, vertical: true).frame(minWidth: 82, alignment: .center)
            }
            .buttonStyle(StudioButtonStyle(treatment: recordingJob ? .recording : .accent))
            .disabled(model.isFinishing || model.isPreparing || (model.isPlaying && model.playbackMode != .record))
            .accessibilityLabel(recordingTitle)
            .help("Record the current webpage · ⇧⌘Return")
        }.labelStyle(.titleAndIcon).fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 8).frame(height: 38)
    }

    private var recordingTitle: String {
        if model.isFinishing { return "Finishing…" }
        if model.isPreparing || (recordingJob && !model.isRecording) { return "Preparing…" }
        return model.isRecording ? "Stop recording" : "Record"
    }

    private var recordingJob: Bool {
        model.isRecording || model.isPreparing || model.isFinishing || (model.isPlaying && model.playbackMode == .record)
    }

    private var broadcastStatus: some View {
        let tint = model.isRecording ? Theme.recording : Theme.accent
        let foreground = model.isRecording ? Color.white : Theme.onAccent
        return HStack(alignment: .center, spacing: 7) {
            Circle().fill(foreground).frame(width: 6, height: 6)
                .padding(4).background(foreground.opacity(0.18), in: Circle())
            Text(model.isRecording ? "ON AIR" : "LIVE")
                .font(.system(size: 12, weight: .heavy, design: .monospaced)).tracking(1.3)
        }
        .foregroundStyle(foreground).frame(width: 114, height: 32)
        .background(tint, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.22)))
        .shadow(color: tint.opacity(0.22), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.isRecording ? "On air, recording" : "Live preview")
    }

    private var canvasArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.theaterMode ? "Theater" : "Live preview").font(.system(size: 23, weight: .semibold)).tracking(-0.6)
                    Text(model.theaterMode ? "Your product, in the spotlight." : "Open your website, set the scene, then press Record.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                broadcastStatus
                VStack(alignment: .trailing, spacing: 4) {
                    Button {
                        model.mode = .studio; model.showInspector = true; model.selectedInspector = "Canvas"
                    } label: {
                        Label("\(model.canvas.width) × \(model.canvas.height)", systemImage: "aspectratio")
                    }.buttonStyle(.plain).help("Canvas settings").accessibilityLabel("Canvas settings")
                    Button {
                        model.mode = .studio; model.showInspector = true; model.selectedInspector = "Export"
                    } label: {
                        Text("\(model.recordingSettings.width) × \(model.recordingSettings.height) · \(model.recordingSettings.fps) fps")
                            .font(.system(size: 11))
                    }.buttonStyle(.plain).help("Video export settings").accessibilityLabel("Video export settings")
                }.font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted).padding(.leading, 3)
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 18)

            if !model.theaterMode {
                WebsiteLocationBar(model: model).padding(.horizontal, 24).padding(.bottom, 14)
            }

            GeometryReader { geometry in
                let scale = max(0.1, min((geometry.size.width - 48) / Double(model.canvas.width),
                                         (geometry.size.height - 42) / Double(model.canvas.height)))
                VStack(spacing: 13) {
                    FilmStageView(model: model, effects: model.effects)
                        .environment(\.colorScheme, .light)
                        .frame(width: Double(model.canvas.width), height: Double(model.canvas.height))
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: Double(model.canvas.width) * scale, height: Double(model.canvas.height) * scale, alignment: .topLeading)
                        .background(StageCaptureAnchor(model: model))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 0.75))
                    HStack(spacing: 6) {
                        Image(systemName: "cursorarrow.motionlines").font(.system(size: 12))
                        Text(model.isFinishing ? "Saving film" : model.isRecording ? "Recording" : model.playbackMode == .design ? "Design preview" : model.isPlaying ? "Script playback" : "Playback complete")
                            .font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11))
                        Text("Fit · \(Int(scale * 100))%").font(.system(size: 12, design: .monospaced))
                    }.foregroundStyle(Theme.muted).frame(width: Double(model.canvas.width) * scale)
                }.frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 7) {
            Text(AppVersion.display)
                .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Theme.accent)
                .help("Showtime \(AppVersion.display)")
                .accessibilityLabel("Showtime version \(AppVersion.number)")
            Rectangle().fill(Theme.line).frame(width: 1, height: 12).padding(.horizontal, 7)
            Button { model.mode = model.isBusy ? .theater : .director } label: {
                HStack(spacing: 6) {
                    Circle().fill(model.agentReady ? Theme.accent : .orange).frame(width: 5, height: 5)
                    Text(model.agentReady ? "Agent ready" : "Agent offline").font(.system(size: 12, weight: .medium))
                }
            }.buttonStyle(.plain)
            Text(model.statusText).font(.system(size: 12)).foregroundStyle(Theme.muted)
                .lineLimit(1).padding(.leading, 12)
            Spacer()
            if model.isRecording || model.isFinishing || model.elapsed > 0 {
                Image(systemName: model.isRecording ? "record.circle" : "clock").foregroundStyle(model.isRecording ? .red : Theme.muted)
                Text(timecode(model.elapsed)).font(.system(size: 12, weight: .medium, design: .monospaced))
                Text("·").foregroundStyle(Theme.muted).padding(.horizontal, 4)
            }
            Image(systemName: "film.stack").font(.system(size: 12)).foregroundStyle(Theme.muted)
            Text("\(model.completedTakes) \(model.completedTakes == 1 ? "take" : "takes")")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
        }.padding(.horizontal, 24).frame(height: 34)
    }
}

private struct WebsiteLocationBar: View {
    @ObservedObject var model: StudioModel
    @State private var address = ""
    @State private var edited = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            BrowserNavigationControls(model: model)
            HStack(spacing: 10) {
                Image(systemName: "globe").foregroundStyle(Theme.accent)
                TextField("Open a website · localhost:3000 or https://your-product.com", text: Binding(get: { address }, set: { value in
                    // AppKit can echo the current field value during focus setup.
                    // Only a real edit should prevent navigation from updating it.
                    guard value != address else { return }
                    address = value; edited = true
                }))
                    .textFieldStyle(.plain).font(.system(size: 13)).focused($focused)
                    .onSubmit(open).accessibilityLabel("Website to record")
                if model.isLoading { ProgressView().controlSize(.small).scaleEffect(0.8) }
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(focused ? Theme.accent.opacity(0.5) : Theme.line))
            Button(action: open) { Label("Open", systemImage: "arrow.up.right") }
                .buttonStyle(StudioButtonStyle()).disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .disabled(model.isPlaying || model.isFinishing || model.isPreparing)
        .onAppear { address = model.actualURL }
        .onChange(of: model.actualURL) { _, url in if !focused || !edited { address = url } }
        .onChange(of: model.addressEditing) { _, editing in
            if editing && !model.canvas.frame.showsBrowserChrome { address = model.actualURL; focused = true }
        }
        .onChange(of: focused) { _, value in if !value && !model.canvas.frame.showsBrowserChrome { model.addressEditing = false } }
    }
    private func open() { focused = false; edited = false; model.navigate(address) }
}

private struct StageCaptureAnchor: NSViewRepresentable {
    let model: StudioModel
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        model.stageView = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { model.stageView = view }
}

func timecode(_ seconds: Double) -> String {
    let value = max(0, Int(seconds))
    return String(format: "%02d:%02d", value / 60, value % 60)
}

struct FilmStageView: View {
    @ObservedObject var model: StudioModel
    let effects: EffectsState

    var body: some View {
        let layout = model.canvas.layout
        let screen = layout.canvasScreen, page = layout.canvasPage
        let outline = Path(layout.screenPath(in: CGRect(origin: .zero, size: screen.size)))
        ZStack(alignment: .topLeading) {
            FilmBackdrop(style: model.canvas.backdrop, canvas: model.canvas)
            ZStack(alignment: .topLeading) {
                WebSurfaceView(model: model).frame(width: page.width, height: page.height)
                    .offset(y: page.minY - screen.minY)
                if model.canvas.frame.showsBrowserChrome {
                    BrowserChromeView(model: model).frame(width: layout.screen.width, height: CanvasSpec.chromeHeight)
                        .scaleEffect(layout.scale, anchor: .topLeading)
                        .frame(width: screen.width, height: CanvasSpec.chromeHeight * layout.scale, alignment: .topLeading)
                }
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .clipShape(outline)
            .overlay(outline.stroke(.black.opacity(0.10), lineWidth: 0.7 * layout.scale).allowsHitTesting(false))
            .offset(x: screen.minX, y: screen.minY)
            AnimationOverlay(model: model)
                .frame(width: Double(model.canvas.width), height: Double(model.canvas.height))
                .allowsHitTesting(false).accessibilityHidden(true)
            EffectsLayer(model: model, effects: effects)
        }
    }
}

private struct EffectsLayer: View {
    let model: StudioModel
    @ObservedObject var effects: EffectsState
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: effects.caption == nil && effects.pulses.isEmpty)) { context in
            EffectsOverlay(model: model, tick: context.date)
        }.allowsHitTesting(false)
    }
}

struct StoryboardView: View {
    @ObservedObject var model: StudioModel
    private var markers: [(index: Int, text: String)] {
        let steps = model.currentScript?.steps ?? []
        let marks = steps.enumerated().filter { $0.element.action == .marker }
            .map { (index: $0.offset, text: $0.element.text ?? $0.element.label ?? "Scene") }
        return marks.isEmpty ? [(0, "Your first scene")] : marks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "film.stack").font(.system(size: 17)).foregroundStyle(Theme.accent)
                Text("Storyboard").font(.system(size: 15, weight: .semibold))
                if let script = model.currentScript {
                    Text("\(script.steps.count) cues")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 7).padding(.vertical, 4).background(Theme.surface, in: Capsule())
                }
                Spacer()
                Button(action: model.importScript) { Label("Import script", systemImage: "square.and.arrow.down") }
                    .buttonStyle(StudioButtonStyle(treatment: .plain)).disabled(model.isBusy)
                Menu {
                    Button("Load Orbit example", systemImage: "sparkles", action: model.loadBundledScript)
                    Button("Open demo website", systemImage: "globe") { model.navigate("showtime://demo") }
                    if model.currentScript != nil {
                        Divider()
                        Button("Clear storyboard", systemImage: "xmark", action: model.clearStoryboard)
                    }
                } label: { Image(systemName: "ellipsis").font(.system(size: 16)).frame(width: 22, height: 28) }
                .menuStyle(.borderlessButton).fixedSize().disabled(model.isBusy)
                .help("Storyboard actions").accessibilityLabel("Storyboard actions")
            }
            if model.currentScript != nil {
                GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(Array(markers.enumerated()), id: \.offset) { position, marker in
                                scene(position: position, marker: marker)
                                    .frame(width: max(146, (geometry.size.width - Double(markers.count - 1) * 10) / Double(markers.count)))
                                    .id(marker.index)
                            }
                        }
                    }.scrollIndicators(.hidden)
                        .onChange(of: model.currentStep) { _, step in
                            if let marker = markers.last(where: { $0.index <= step }) {
                                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(marker.index) }
                            }
                        }
                }
                }.frame(height: 70)
                HStack(spacing: 7) {
                Text(model.scriptName).font(.system(size: 12)).lineLimit(1)
                Spacer()
                if model.isPlaying {
                    Text("Cue \(model.currentStep + 1) of \(model.currentScript?.steps.count ?? 0)")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent)
                } else {
                    Button { model.playStoryboard(record: true) } label: {
                        Label("Record storyboard", systemImage: "record.circle")
                    }.buttonStyle(StudioButtonStyle()).disabled(model.isBusy)
                        .help("Run this storyboard and export a new MP4 using the current video settings")
                }
                }.foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Let your agent direct the next take.").font(.system(size: 14, weight: .medium))
                        Text("Create a storyboard with AI Director, or use Record to capture the current webpage.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button { model.mode = .director } label: { Label("AI Director", systemImage: "sparkles") }
                        .buttonStyle(StudioButtonStyle()).disabled(model.isBusy)
                }.padding(.bottom, 2)
            }
        }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 20)
    }

    private func scene(position: Int, marker: (index: Int, text: String)) -> some View {
        let end = position + 1 < markers.count ? markers[position + 1].index : (model.currentScript?.steps.count ?? 1)
        let active = model.currentStep >= marker.index && model.currentStep < end
        let finished = model.currentStep >= end
        let progress = finished ? 1 : (active ? Double(model.currentStep - marker.index + 1) / Double(max(1, end - marker.index)) : 0)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Text(String(format: "%02d", position + 1))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? Theme.accent : Theme.muted)
                Text(marker.text).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if finished {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.accent)
                } else if active {
                    Image(systemName: "play.fill").font(.system(size: 9)).foregroundStyle(Theme.accent)
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent.opacity(0.10))
                    Capsule().fill(Theme.accent.opacity(active ? 1 : 0.45)).frame(width: geometry.size.width * progress)
                }
            }.frame(height: 3)
        }
        .padding(13).frame(height: 68)
        .background(active ? Theme.accent.opacity(0.055) : Theme.field, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(active ? Theme.accent.opacity(0.3) : Theme.line, lineWidth: 0.75))
        .help(marker.text)
        .accessibilityElement(children: .combine)
    }
}
