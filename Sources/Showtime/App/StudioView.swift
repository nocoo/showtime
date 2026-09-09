import AppKit
import SwiftUI
import ShowtimeCore

enum Theme {
    static let ink = Color(red: 0.145, green: 0.192, blue: 0.149)
    static let muted = Color(red: 0.431, green: 0.478, blue: 0.431)
    static let accentHex = "#4A8234"
    static let accent = Color(red: 74 / 255, green: 130 / 255, blue: 52 / 255)
    static let sprout = Color(red: 207 / 255, green: 232 / 255, blue: 181 / 255)
    static let line = Color.black.opacity(0.065)
    static let surface = Color(red: 246 / 255, green: 248 / 255, blue: 244 / 255)
}

struct StudioView: View {
    @ObservedObject var model: StudioModel
    @State private var theater = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    canvasArea.frame(maxHeight: .infinity)
                    if !theater {
                        Rectangle().fill(Theme.line).frame(height: 1)
                        StoryboardView(model: model)
                    }
                }
                if model.showInspector && !theater {
                    Rectangle().fill(Theme.line).frame(width: 1)
                    InspectorView(model: model, effects: model.effects).frame(width: 294)
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            statusBar
        }
        .background(Theme.surface)
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $model.showConnection) { ConnectionView(model: model) }
        .overlay(alignment: .top) {
            if let error = model.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    Text(error).font(.system(size: 14)).lineLimit(3)
                    Spacer()
                    Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.25)))
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 5).padding(.horizontal, 100).padding(.top, 72)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Theme.ink).frame(width: 31, height: 31)
                Image(systemName: "play.rectangle.fill").font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.sprout)
            }
            Text("showtime").font(.system(size: 20, weight: .semibold, design: .rounded)).tracking(-0.6)
            Text("STUDIO").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(Theme.muted)
                .padding(.horizontal, 7).padding(.vertical, 4).overlay(Capsule().strokeBorder(Theme.line))
            Spacer()
            HStack(spacing: 3) {
                modeButton("Studio", selected: !theater) { theater = false }
                modeButton("Theater", selected: theater) { theater = true }
            }.padding(3).background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            Spacer()
            Button(action: model.revealExport) { Image(systemName: "folder").font(.system(size: 16)).frame(width: 29, height: 29) }
                .buttonStyle(.plain).foregroundStyle(Theme.muted).help("Show exports")
            Button { model.playDemo(record: false) } label: {
                Label("Rehearse", systemImage: "play").font(.system(size: 14, weight: .medium)).padding(.horizontal, 13).frame(height: 36)
            }.buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line)).disabled(model.isBusy)
            Button {
                if model.isPlaying { model.director.cancel() }
                else if model.isRecording { model.toggleRecording() }
                else { model.playDemo(record: true) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: model.isPlaying || model.isRecording ? "stop.fill" : "record.circle").font(.system(size: 14, weight: .semibold))
                    Text(model.isPreparing ? "Preparing…" : (model.isFinishing ? "Finishing…" : (model.isPlaying || model.isRecording ? "Stop take" : "Record film"))).font(.system(size: 14, weight: .semibold))
                }.foregroundStyle(.white).padding(.horizontal, 14).frame(height: 36)
                    .background(model.isPlaying || model.isRecording ? Color(red: 0.82, green: 0.27, blue: 0.32) : Theme.accent, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain).disabled(model.isFinishing || model.isPreparing).help("Run the storyboard and export an MP4")
        }
        .padding(.horizontal, 28).frame(height: 68).background(.white.opacity(0.9))
    }

    private func modeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Theme.ink : Theme.muted).padding(.horizontal, 16).frame(height: 30)
                .background(selected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(selected ? 0.04 : 0), radius: 2, y: 1)
        }.buttonStyle(.plain)
    }

    private var canvasArea: some View {
        GeometryReader { geometry in
            let scale = max(0.1, min((geometry.size.width - 56) / Double(model.canvas.width), (geometry.size.height - 104) / Double(model.canvas.height)))
            VStack(spacing: 14) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2).fill(model.isRecording ? Color.red : Theme.accent).frame(width: 6, height: 6)
                    Text(model.isRecording ? "ON AIR" : "LIVE CANVAS").font(.system(size: 11, weight: .bold)).tracking(1.5)
                    Spacer()
                    Text("\(model.canvas.width) × \(model.canvas.height)").font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text("·").padding(.horizontal, 2)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11))
                    Text("Fit").font(.system(size: 12, weight: .medium))
                }.foregroundStyle(Theme.muted).frame(width: Double(model.canvas.width) * scale)
                FilmStageView(model: model, effects: model.effects)
                    .frame(width: Double(model.canvas.width), height: Double(model.canvas.height))
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: Double(model.canvas.width) * scale, height: Double(model.canvas.height) * scale, alignment: .topLeading)
                    .background(StageCaptureAnchor(model: model))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.065), lineWidth: 1))
                    .shadow(color: .black.opacity(0.065), radius: 22, x: 0, y: 10)
                HStack(spacing: 5) {
                    Image(systemName: "cursorarrow.motionlines").font(.system(size: 12))
                    Text("Real interaction. A little movie magic.").font(.system(size: 12))
                    Spacer()
                    Text("\(Int(scale * 100))%").font(.system(size: 12, design: .monospaced))
                }.foregroundStyle(Theme.muted.opacity(0.8)).frame(width: Double(model.canvas.width) * scale)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 7) {
            Text(AppVersion.display)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.accent.opacity(0.07), in: Capsule())
                .help("Showtime \(AppVersion.display)")
                .accessibilityLabel("Showtime version \(AppVersion.number)")
            Rectangle().fill(Theme.line).frame(width: 1, height: 12).padding(.horizontal, 5)
            Button { model.showConnection = true } label: {
                HStack(spacing: 6) {
                    Circle().fill(model.agentReady ? Color(red: 0.26, green: 0.65, blue: 0.47) : .orange).frame(width: 5, height: 5)
                    Text(model.agentReady ? "Agent ready" : "Agent offline").font(.system(size: 12, weight: .medium))
                }
            }.buttonStyle(.plain)
            Text("/").foregroundStyle(Theme.muted.opacity(0.35)).padding(.horizontal, 7)
            Text(model.statusText).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
            Spacer()
            if model.isRecording || model.isFinishing || model.elapsed > 0 {
                Circle().fill(model.isRecording ? Color.red : Theme.muted.opacity(0.5)).frame(width: 5, height: 5)
                Text(timecode(model.elapsed)).font(.system(size: 12, weight: .medium, design: .monospaced))
                Text("·").foregroundStyle(Theme.muted)
            }
            Text("\(model.completedTakes) \(model.completedTakes == 1 ? "take" : "takes")").font(.system(size: 12)).foregroundStyle(Theme.muted)
            if !model.showInspector || theater {
                Button { theater = false; model.showInspector = true } label: { Image(systemName: "sidebar.right") }.buttonStyle(.plain).padding(.leading, 8).help("Show director")
            }
        }.padding(.horizontal, 28).frame(height: 34).background(.white.opacity(0.82))
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
        let marks = steps.enumerated().filter { $0.element.action == .marker }.map { (index: $0.offset, text: $0.element.text ?? $0.element.label ?? "Scene") }
        return marks.isEmpty ? [(0, "Your first scene")] : marks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 9) {
                Image(systemName: "film.stack").font(.system(size: 15)).foregroundStyle(Theme.accent)
                Text(model.scriptName).font(.system(size: 14, weight: .semibold))
                Text("\(model.currentScript?.steps.count ?? 0) cues").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Theme.surface, in: Capsule())
                Spacer()
                Button(action: model.importScript) {
                    Label("Import script", systemImage: "square.and.arrow.down").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                }.buttonStyle(.plain).disabled(model.isBusy)
                Menu {
                    Button("Load Orbit example", action: model.loadBundledScript)
                    Button("Start manual recording", action: model.toggleRecording)
                    Button("Open demo website") { model.navigate("showtime://demo") }
                } label: { Image(systemName: "ellipsis").font(.system(size: 15)).frame(width: 22) }.menuStyle(.borderlessButton).fixedSize().disabled(model.isBusy)
            }
            HStack(spacing: 8) {
                ForEach(Array(markers.enumerated()), id: \.offset) { position, marker in
                    let end = position + 1 < markers.count ? markers[position + 1].index : (model.currentScript?.steps.count ?? 1)
                    let active = model.currentStep >= marker.index && model.currentStep < end
                    let finished = model.currentStep >= end
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 7) {
                            Text(String(format: "%02d", position + 1)).font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(active ? Theme.accent : Theme.muted.opacity(0.65))
                            Text(marker.text).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 0)
                            if finished { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent) }
                        }
                        GeometryReader { geo in
                            let progress = finished ? 1 : (active ? Double(model.currentStep - marker.index + 1) / Double(max(1, end - marker.index)) : 0)
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.accent.opacity(0.1))
                                Capsule().fill(Theme.accent.opacity(active ? 1 : 0.45)).frame(width: geo.size.width * progress)
                            }
                        }.frame(height: 3)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12).frame(maxWidth: .infinity)
                    .background(active ? Theme.accent.opacity(0.055) : Theme.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(active ? Theme.accent.opacity(0.2) : Theme.line, lineWidth: 0.7))
                }
            }
            HStack(spacing: 6) {
                Text("THE STORYBOARD").font(.system(size: 10, weight: .bold)).tracking(1.3)
                Text("·").padding(.horizontal, 3)
                Text(model.isPlaying ? "Cue \(model.currentStep + 1) of \(model.currentScript?.steps.count ?? 0)" : "Every move, on purpose.").font(.system(size: 11))
                Spacer()
                Text("⌘ ↵").font(.system(size: 11)).padding(.horizontal, 4).padding(.vertical, 2).background(Theme.surface, in: RoundedRectangle(cornerRadius: 3))
                Text("to rehearse").font(.system(size: 11))
            }.foregroundStyle(Theme.muted)
        }.padding(.horizontal, 28).padding(.vertical, 20).background(.white.opacity(0.86))
    }
}
