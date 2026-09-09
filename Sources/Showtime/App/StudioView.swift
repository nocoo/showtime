import AppKit
import SwiftUI
import ShowtimeCore

struct StudioView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sidebarVisible: Bool { model.showInspector && !model.theaterMode }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                if sidebarVisible {
                    InspectorView(model: model, effects: model.effects)
                        .frame(width: 280)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                VStack(spacing: 0) {
                    canvasArea.frame(maxHeight: .infinity)
                    if !model.theaterMode {
                        Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 24)
                        StoryboardView(model: model)
                    }
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line, lineWidth: 0.75))
            }
            .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: sidebarVisible)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: model.theaterMode)
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
        .sheet(isPresented: $model.showConnection) { ConnectionView(model: model) }
        .overlay(alignment: .top) {
            if let error = model.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    Text(error).font(.system(size: 14)).lineLimit(3)
                    Spacer()
                    Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(StudioButtonStyle(treatment: .plain)).accessibilityLabel("Dismiss error")
                }
                .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.25)))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 5)
                .padding(.horizontal, 100).padding(.top, 12)
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: AppResources.brandMark)
                    .resizable().renderingMode(.original).interpolation(.high).scaledToFit()
                    .frame(width: 34, height: 34).accessibilityHidden(true)
                Text("showtime").font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(-0.6)
            }.allowsHitTesting(false)
            Button {
                if model.theaterMode { model.theaterMode = false; model.showInspector = true }
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
            modeButton("Studio", symbol: "rectangle.leftthird.inset.filled", selected: !model.theaterMode) {
                model.theaterMode = false
            }
            modeButton("Theater", symbol: "rectangle.inset.filled", selected: model.theaterMode) {
                model.theaterMode = true
            }
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
            Button(action: model.revealExport) { Image(systemName: "folder") }
                .buttonStyle(StudioButtonStyle(treatment: .plain))
                .help("Show exports").accessibilityLabel("Show exports")
            Button { model.playDemo(record: false) } label: { Label("Rehearse", systemImage: "play") }
                .buttonStyle(StudioButtonStyle()).disabled(model.isBusy)
                .help("Rehearse the storyboard · ⌘Return")
            Button {
                if model.isPlaying { model.director.cancel() }
                else if model.isRecording { model.toggleRecording() }
                else { model.playDemo(record: true) }
            } label: {
                Label(recordingTitle, systemImage: model.isPlaying || model.isRecording ? "stop.fill" : "record.circle")
                    .fontWeight(.semibold).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 82)
            }
            .buttonStyle(StudioButtonStyle(treatment: model.isPlaying || model.isRecording ? .recording : .accent))
            .disabled(model.isFinishing || model.isPreparing)
            .help("Run the storyboard and export an MP4 · ⇧⌘Return")
        }.labelStyle(.titleAndIcon).fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 8).frame(height: 38)
    }

    private var recordingTitle: String {
        if model.isPreparing { return "Preparing…" }
        if model.isFinishing { return "Finishing…" }
        return model.isPlaying || model.isRecording ? "Stop take" : "Record"
    }

    private var canvasArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live preview").font(.system(size: 23, weight: .semibold)).tracking(-0.6)
                    Text("A real browser. Ready for its close-up.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle().fill(model.isRecording ? .red : Theme.accent).frame(width: 6, height: 6)
                    Text(model.isRecording ? "On air" : "Live").font(.system(size: 12, weight: .medium))
                }.foregroundStyle(model.isRecording ? .red : Theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((model.isRecording ? Color.red : Theme.accent).opacity(0.07), in: Capsule())
                Label("\(model.canvas.width) × \(model.canvas.height)", systemImage: "aspectratio")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                    .padding(.leading, 3)
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 18)

            GeometryReader { geometry in
                let scale = max(0.1, min((geometry.size.width - 48) / Double(model.canvas.width),
                                         (geometry.size.height - 42) / Double(model.canvas.height)))
                VStack(spacing: 13) {
                    FilmStageView(model: model, effects: model.effects)
                        .frame(width: Double(model.canvas.width), height: Double(model.canvas.height))
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: Double(model.canvas.width) * scale, height: Double(model.canvas.height) * scale, alignment: .topLeading)
                        .background(StageCaptureAnchor(model: model))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 0.75))
                    HStack(spacing: 6) {
                        Image(systemName: "cursorarrow.motionlines").font(.system(size: 12))
                        Text(model.isPlaying ? "Directing cue \(model.currentStep + 1)" : "Interact with the page to set the scene")
                            .font(.system(size: 12))
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
            Button { model.showConnection = true } label: {
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
        ZStack {
            FilmBackdrop(style: model.canvas.backdrop)
            VStack(spacing: 0) {
                BrowserChromeView(model: model).frame(height: CanvasSpec.chromeHeight)
                WebSurfaceView(model: model).frame(width: model.canvas.pageWidth, height: model.canvas.pageHeight)
            }
            .frame(width: model.canvas.pageWidth, height: Double(model.canvas.height) - model.canvas.inset * 2)
            .background(.white).clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.black.opacity(0.10), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.19), radius: 25, x: 0, y: 9)
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
                Text("\(model.currentScript?.steps.count ?? 0) cues")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 7).padding(.vertical, 4).background(Theme.surface, in: Capsule())
                Spacer()
                Button(action: model.importScript) { Label("Import script", systemImage: "square.and.arrow.down") }
                    .buttonStyle(StudioButtonStyle(treatment: .plain)).disabled(model.isBusy)
                Menu {
                    Button("Load Orbit example", systemImage: "sparkles", action: model.loadBundledScript)
                    Button("Start manual recording", systemImage: "record.circle", action: model.toggleRecording)
                    Button("Open demo website", systemImage: "globe") { model.navigate("showtime://demo") }
                } label: { Image(systemName: "ellipsis").font(.system(size: 16)).frame(width: 22, height: 28) }
                .menuStyle(.borderlessButton).fixedSize().disabled(model.isBusy)
                .help("Storyboard actions").accessibilityLabel("Storyboard actions")
            }
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
                    Text("⌘ ↵").font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Theme.surface, in: RoundedRectangle(cornerRadius: 4))
                    Text("to rehearse").font(.system(size: 12))
                }
            }.foregroundStyle(Theme.muted)
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
