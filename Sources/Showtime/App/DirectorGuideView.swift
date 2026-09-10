import AppKit
import SwiftUI
import ShowtimeCore

enum AgentGuide {
    static func tool(_ name: String) -> URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Tools/" + name),
           FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("scripts/" + name)
    }

    static var mcpConfiguration: String {
        let value: [String: Any] = ["mcpServers": ["showtime": ["command": "python3", "args": [tool("showtime_mcp.py").path]]]]
        return String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }

    static var cli: String { shellQuote(tool("showtime").path) }
    private static func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }

    static func prompt(website: String, brief: String, seconds: Int, exportFolder: URL, canvas: CanvasSpec, video: RecordingSpec) -> String {
        """
Direct a polished \(seconds)-second product demo in the running Showtime macOS app and export an MP4.

Website: \(website.trimmingCharacters(in: .whitespacesAndNewlines))
Creative brief: \(brief.trimmingCharacters(in: .whitespacesAndNewlines))
Output folder: \(exportFolder.path)

Connection:
- If Showtime MCP tools are available, start with showtime_status and showtime_studio(mode: "theater").
- Otherwise use the bundled CLI, which reads the local connection automatically:
  \(cli) status
  \(cli) studio --mode theater
  \(cli) --help
- MCP bridge, if configuration is needed:
  python3 \(shellQuote(tool("showtime_mcp.py").path))
  Keep Showtime open while directing.

Direction:
1. Open the website using showtime_open or the CLI open command. Use showtime_inspect / CLI inspect to discover visible controls and selectors before clicking.
2. Plan a short story with a clear opening, 3–5 meaningful moments, and a closing frame. Give every cue a short, human-readable label; use marker actions to name each scene. Showtime shows these labels and progress in Theater.
3. Write a repeatable JSON film script. Top-level shape:
   {"version":1,"name":"Product demo","canvas":{"width":\(canvas.width),"height":\(canvas.height),"inset":\(canvas.inset),"backdrop":"\(canvas.backdrop)","browserTheme":"\(canvas.browserTheme)"},"recording":{"output":"ABSOLUTE_NEW_PATH.mp4","width":\(video.width),"height":\(video.height),"fps":\(video.fps)},"steps":[...]}
   These are the user's current Canvas and video settings. Keep them unless the creative brief requests a different format. showtime_settings / CLI settings can read or adjust them before a take.
   Use a new output filename in the folder above; existing files are never overwritten.
4. Direct real mouse and keyboard input with move, click, doubleClick, drag, scroll, type, and key actions. Targets use selector or x/y in the unzoomed webpage viewport. Use a real system hand/arrow or a focus ring, deliberate cursor movement, short camera zooms, and restrained animated captions.
5. Useful effect examples:
   {"action":"cursor","style":"hand","size":36,"clickEffect":true}
   {"action":"zoom","selector":"#target","scale":1.5,"duration":0.9,"label":"Focus on the feature"}
   {"action":"caption","text":"Your headline","style":"glass","position":"bottom","duration":3}
   {"action":"wait","duration":1.2}
   Caption duration does not pause the script; add waits deliberately. Parallel groups can combine one move, one zoom, one caption, and waits. Use assert actions to check page responses. Keep the real page title and URL unless the creative brief requests overrides.
6. Rehearse with showtime_run(rehearse: true) or CLI run SCRIPT.json --rehearse. Inspect a composed screenshot, refine pacing, then run with recording enabled. MCP showtime_run returns a job ID; follow it with showtime_job. The CLI can use run SCRIPT.json --output NEW_PATH.mp4 and wait for completion.
7. Confirm the completed job and the playable H.264 MP4 at \(video.width) × \(video.height), \(video.fps) fps. Return the movie path and the saved script. The export contains the film canvas; Studio controls and director activity stay in the app. Showtime records silent video.

Available action kinds: open, metadata, move, click, doubleClick, drag, scroll, type, key, wait, waitFor, zoom, caption, cursor, marker, assert, evaluate, screenshot, parallel.
Use the MCP input schemas or CLI help for exact arguments. Work autonomously through rehearsal, verification, and export.
"""
    }
}

struct DirectorGuideView: View {
    @ObservedObject var model: StudioModel
    @State private var website = "showtime://demo"
    @State private var brief = "Introduce the product, highlight its most useful workflow, and finish with a memorable closing frame. Keep the pacing calm and confident."
    @State private var seconds = 45
    @State private var showConfiguration = false
    @State private var showFullPrompt = false

    private var prompt: String {
        AgentGuide.prompt(website: website, brief: brief, seconds: seconds, exportFolder: model.exportFolder,
                          canvas: model.canvas, video: model.recordingSettings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                HStack(alignment: .top, spacing: 24) {
                    guideStep("01", title: "Connect your agent", symbol: "point.3.connected.trianglepath.dotted",
                              detail: "Use the MCP bridge or the CLI that comes with Showtime.")
                    guideStep("02", title: "Give it a direction", symbol: "text.bubble",
                              detail: "Share your website and the moments worth showing.")
                    guideStep("03", title: "Watch the story unfold", symbol: "play.rectangle",
                              detail: "Follow each cue in Theater, then collect your finished MP4.")
                }
                briefComposer
                configuration
            }
            .frame(maxWidth: 1160).padding(32).frame(maxWidth: .infinity)
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line, lineWidth: 0.75))
        .onAppear {
            if !model.actualURL.isEmpty, !model.actualURL.hasPrefix(model.demoURL.absoluteString) { website = model.actualURL }
        }
        .onChange(of: model.mode) { _, mode in
            if mode == .director, website == "showtime://demo", !model.actualURL.isEmpty,
               !model.actualURL.hasPrefix(model.demoURL.absoluteString) { website = model.actualURL }
        }
    }

    private var hero: some View {
        HStack(spacing: 36) {
            VStack(alignment: .leading, spacing: 14) {
                Label("YOUR CREATIVE COPILOT", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold)).tracking(1.3).foregroundStyle(Theme.accent)
                Text("Give your agent\nthe director’s chair.")
                    .font(.system(size: 34, weight: .semibold)).tracking(-1).fixedSize(horizontal: false, vertical: true)
                Text("Describe the story. Your agent directs the real browser, while you watch in Theater.")
                    .font(.system(size: 15)).foregroundStyle(Theme.muted).lineSpacing(5).frame(maxWidth: 440, alignment: .leading)
                HStack(spacing: 12) {
                    Button {
                        model.mode = .theater
                        model.loadBundledScript()
                        model.playStoryboard(record: false)
                    } label: { Label("Watch an example", systemImage: "play") }
                        .buttonStyle(StudioButtonStyle()).disabled(model.isBusy)
                    HStack(spacing: 6) {
                        Circle().fill(model.agentReady ? Theme.accent : .orange).frame(width: 6, height: 6)
                        Text(model.agentReady ? "Ready for your agent" : "Starting connection…")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }.padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            DirectorFlowIllustration().frame(width: 370, height: 222)
        }
    }

    private func guideStep(_ number: String, title: String, symbol: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(Theme.accent)
                Text(number).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Theme.muted)
            }
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var briefComposer: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil").foregroundStyle(Theme.accent)
                Text("One brief. A complete film.").font(.system(size: 19, weight: .semibold)).tracking(-0.3)
                Spacer()
                Label("\(model.recordingSettings.width) × \(model.recordingSettings.height) · \(model.recordingSettings.fps) fps", systemImage: "film")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    fieldLabel("Website")
                    TextField("https://your-product.com", text: $website)
                        .font(.system(size: 14)).textFieldStyle(.plain).padding(12)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
                        .accessibilityLabel("Website for the director")
                    fieldLabel("What should the viewer remember?")
                    TextEditor(text: $brief).font(.system(size: 14)).scrollContentBackground(.hidden)
                        .padding(8).frame(height: 86).background(Theme.panel, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
                        .accessibilityLabel("Creative brief")
                    HStack(spacing: 14) {
                        fieldLabel("Target length")
                        StudioSegmentedPicker(title: "Target length", choices: [(30, "30 sec"), (45, "45 sec"), (60, "60 sec")], selection: $seconds)
                            .frame(width: 230)
                        Spacer(minLength: 0)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 15) {
                    Text("Your agent gets everything it needs.").font(.system(size: 15, weight: .semibold))
                    handoffRow("link", "The exact connection to this app")
                    handoffRow("film.stack", "A plan, a rehearsal, and a final take")
                    handoffRow("cursorarrow.click", "Real clicks, camera work, and captions")
                    handoffRow("checkmark.seal", "A verified movie and a reusable script")
                    Spacer(minLength: 0)
                    Button { model.copyForAgent(prompt, title: "Director brief copied") } label: {
                        Label("Copy instructions for your agent", systemImage: "doc.on.doc")
                    }.buttonStyle(StudioButtonStyle(treatment: .accent))
                        .disabled(website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("copyDirectorBrief")
                    Text("Paste into your coding agent. Showtime handles the browser and the recording.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
                }.frame(width: 330, alignment: .leading)
            }
            DisclosureGroup("Preview the full instructions", isExpanded: $showFullPrompt) {
                Text(prompt).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12).lineSpacing(4)
            }.font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
        }
        .padding(24).background(Theme.field, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.75))
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 14) {
            DisclosureGroup(isExpanded: $showConfiguration) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MCP configuration").font(.system(size: 14, weight: .semibold))
                        Text(AgentGuide.mcpConfiguration).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
                        Button { model.copyForAgent(AgentGuide.mcpConfiguration, title: "MCP configuration copied") } label: {
                            Label("Copy MCP configuration", systemImage: "doc.on.doc")
                        }.buttonStyle(StudioButtonStyle())
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Built-in CLI").font(.system(size: 14, weight: .semibold))
                        Text("An agent with terminal access can start immediately. The CLI and MCP bridge connect to this running app automatically.")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
                        Text(AgentGuide.cli + " status").font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
                        Button { model.copyForAgent(AgentGuide.cli + " status", title: "CLI command copied") } label: {
                            Label("Copy connection command", systemImage: "doc.on.doc")
                        }.buttonStyle(StudioButtonStyle())
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.top, 18)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal").foregroundStyle(Theme.accent)
                    Text("Connection details").font(.system(size: 14, weight: .medium))
                    Text("MCP or CLI").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(Theme.muted)
                Text("Films are saved to Movies / Showtime").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Button("Open exports", action: model.revealExport).buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent)
            }.padding(.top, 6)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
    }

    private func handoffRow(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol).font(.system(size: 13)).foregroundStyle(Theme.muted)
            .labelStyle(.titleAndIcon)
    }
}

private struct DirectorFlowIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Theme.accent.opacity(0.055))
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    node("sparkles", title: "Your agent")
                    Image(systemName: "arrow.right").font(.system(size: 13)).foregroundStyle(Theme.accent.opacity(0.5))
                    node(Image(nsImage: AppResources.directorBrowser), title: "Showtime")
                    Image(systemName: "arrow.right").font(.system(size: 13)).foregroundStyle(Theme.accent.opacity(0.5))
                    node("film", title: "Your film")
                }
                HStack(spacing: 10) {
                    ForEach([("cursorarrow.motionlines", "Direct"), ("viewfinder", "Focus"), ("text.bubble", "Tell the story")], id: \.0) { symbol, title in
                        Label(title, systemImage: symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Theme.panel, in: Capsule())
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your agent directs Showtime with real mouse movement, camera focus, and captions to create your film.")
    }
    private func node(_ symbol: String, title: String) -> some View {
        node(Image(systemName: symbol), title: title)
    }
    private func node(_ image: Image, title: String) -> some View {
        VStack(spacing: 8) {
            image.resizable().scaledToFit().fontWeight(.light).frame(width: 25, height: 25).foregroundStyle(Theme.accent)
                .frame(width: 56, height: 56).background(Theme.panel, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(Theme.line))
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
        }.frame(width: 78)
    }
}
