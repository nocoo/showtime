import AppKit
import SwiftUI
import ShowtimeCore

enum AgentGuide {
    enum Installation { case missing, updateAvailable, current }
    private static let toolNames = ["showtime", "showtime_cli.py", "showtime_client.py", "showtime_mcp.py", "showtime_version.py", "package.json"]

    static var toolsFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Showtime/bin", isDirectory: true)
    }

    static var installation: Installation {
        let fm = FileManager.default
        guard fm.fileExists(atPath: toolsFolder.appendingPathComponent("showtime").path) else { return .missing }
        guard fm.isExecutableFile(atPath: toolsFolder.appendingPathComponent("showtime").path),
              let source = Bundle.main.resourceURL?.appendingPathComponent("Tools", isDirectory: true),
              toolNames.allSatisfy({ name in
                  guard let bundled = try? Data(contentsOf: source.appendingPathComponent(name)),
                        let installed = try? Data(contentsOf: toolsFolder.appendingPathComponent(name)) else { return false }
                  return bundled == installed
              }) else { return .updateAvailable }
        return .current
    }

    /// User-owned tools survive App Translocation, renames, and app upgrades.
    /// Only the explicit Install / Update button calls this; startup and copying never install.
    static func installTools() throws {
        guard let source = Bundle.main.resourceURL?.appendingPathComponent("Tools", isDirectory: true) else {
            throw ShowtimeError("Showtime's bundled agent tools are missing. Reinstall the app.")
        }
        let files = try toolNames.map { ($0, try Data(contentsOf: source.appendingPathComponent($0))) }
        let fm = FileManager.default
        try fm.createDirectory(at: toolsFolder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for (name, data) in files {
            let destination = toolsFolder.appendingPathComponent(name)
            if (try? Data(contentsOf: destination)) != data { try data.write(to: destination, options: .atomic) }
            try fm.setAttributes([.posixPermissions: name == "showtime" ? 0o755 : 0o600], ofItemAtPath: destination.path)
        }
    }

    /// The launcher skips Apple's installer shim. Probe only after a user action,
    /// off the UI thread, with a deadline for slow interpreter/version-manager startup.
    static func checkPython() async -> Bool {
        await Task.detached {
            let process = Process()
            process.executableURL = toolsFolder.appendingPathComponent("showtime")
            process.arguments = ["--version"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return false }
            let deadline = Date().addingTimeInterval(8)
            while process.isRunning, Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
            if process.isRunning { process.terminate(); return false }
            return process.terminationStatus == 0
        }.value
    }

    static var mcpConfiguration: String {
        // MCP clients do not expand ~ or $HOME in plain JSON arguments. Let
        // the shell expand this fixed, quoted path without embedding a username.
        let value: [String: Any] = ["mcpServers": ["showtime": ["command": "/bin/sh", "args": ["-c", #"exec "$HOME/Library/Application Support/Showtime/bin/showtime" mcp"#]]]]
        return String(decoding: try! JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }

    static let cliSetup = #"export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH""#
    static let connectionCommand = cliSetup + "\nshowtime status"

    static func prompt(website: String, brief: String, seconds: Int, exportFolder: URL, canvas: CanvasSpec, video: RecordingSpec, toolsInstalled: Bool, pythonReady: Bool?) -> String {
        let cliPreparation: String
        if !toolsInstalled {
            cliPreparation = "For CLI access, first have the user select Install tools (or Update tools) in Showtime → AI Director → Agent integration. Python 3.10+ is required; that page provides a download link if needed. Opening Showtime or copying this brief does not install tools."
        } else if pythonReady == false {
            cliPreparation = "The CLI is installed, but Python 3.10+ could not be started. Before using the CLI, have the user install Python via AI Director → Agent integration → Download Python, then select Check Python."
        } else {
            cliPreparation = "The Showtime CLI is installed in the user's tools folder. It requires Python 3.10+."
        }
        return """
Direct a polished \(seconds)-second product demo in the running Showtime macOS app and export an MP4.

Website: \(website.trimmingCharacters(in: .whitespacesAndNewlines))
Creative brief: \(brief.trimmingCharacters(in: .whitespacesAndNewlines))
Output folder: \(exportFolder.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path + "/", with: "~/"))

Connection:
- If Showtime MCP tools are available, start with showtime_status and showtime_studio(mode: "theater").
- \(cliPreparation) Add the CLI to this terminal session once:
  \(cliSetup)
  showtime status
  showtime studio --mode theater
  showtime --help
  Repeat the PATH setup in a new shell; no source checkout or app bundle path is needed.
- To configure MCP, run showtime mcp-config after the setup above, or copy the configuration from AI Director → Connection details. showtime mcp starts the stdio bridge.
  Keep Showtime open while directing. CLI and MCP discover the local connection automatically.

Direction:
1. Open the website using showtime_open or the CLI open command. Use showtime_inspect / CLI inspect to discover visible controls and selectors before clicking.
2. Plan a short story with a clear opening, 3–5 meaningful moments, and a closing frame. Give every cue a short, human-readable label; use marker actions to name each scene. Showtime shows these labels and progress in Theater.
3. Write a repeatable JSON film script. Top-level shape:
   {"version":1,"name":"Product demo","canvas":{"width":\(canvas.width),"height":\(canvas.height),"inset":\(canvas.inset),"backdrop":"\(canvas.backdrop)","browserTheme":"\(canvas.browserTheme)","frame":"\(canvas.frame.rawValue)"},"recording":{"output":"ABSOLUTE_NEW_PATH.mp4","width":\(video.width),"height":\(video.height),"fps":\(video.fps)},"steps":[...]}
   These are the user's current Canvas and video settings. Keep them unless the creative brief requests a different format. showtime_settings / CLI settings can read or adjust them before a take.
   Current frame: \(canvas.frame.title). Webpage viewport: \(Int(canvas.pageWidth)) × \(Int(canvas.pageHeight)) CSS pixels. Device frames are included in the film and keep a responsive viewport independent of Canvas size. After changing frame, inspect again before choosing targets. Phone/tablet frames show device status UI instead of desktop browser chrome.
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
    @State private var installation = AgentGuide.installation
    @State private var isSettingUp = false
    @State private var pythonReady: Bool?

    private var prompt: String {
        AgentGuide.prompt(website: website, brief: brief, seconds: seconds, exportFolder: model.exportFolder,
                          canvas: model.canvas, video: model.recordingSettings, toolsInstalled: installation == .current, pythonReady: pythonReady)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                HStack(alignment: .top, spacing: 24) {
                    guideStep("01", title: "Connect your agent", symbol: "point.3.connected.trianglepath.dotted",
                              detail: "Install the optional tools below, or use an existing MCP connection.")
                    guideStep("02", title: "Give it a direction", symbol: "text.bubble",
                              detail: "Share your website and the moments worth showing.")
                    guideStep("03", title: "Watch the story unfold", symbol: "play.rectangle",
                              detail: "Follow each cue in Theater, then collect your finished MP4.")
                }
                agentIntegration
                briefComposer
                exportLocation
            }
            .frame(maxWidth: 1160).padding(32).frame(maxWidth: .infinity)
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.line, lineWidth: 0.75))
        .onAppear {
            if !model.actualURL.isEmpty, !model.actualURL.hasPrefix(model.demoURL.absoluteString) { website = model.actualURL }
        }
        .onChange(of: model.mode) { _, mode in
            if mode == .director { installation = AgentGuide.installation }
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
                        Text(model.agentReady ? "Local connection ready" : "Starting connection…")
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
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }

    private var agentIntegration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Label("Agent integration", systemImage: "terminal")
                            .font(.system(size: 18, weight: .semibold))
                        Text(installation == .missing ? "Not installed" : installation == .current ? "Installed" : "Update available")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Theme.accent.opacity(0.08), in: Capsule())
                    }
                    Text("Optional CLI + MCP bridge for your agent. Requires Python 3.10 or later.")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    Text("Installs to ~/Library/Application Support/Showtime/bin")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { setUpAgentTools(install: installation != .current) } label: {
                    Label(isSettingUp ? "Checking…" : installation == .missing ? "Install tools" : installation == .current ? "Check Python" : "Update tools",
                          systemImage: installation == .current ? "arrow.clockwise" : "arrow.down.circle")
                }.buttonStyle(StudioButtonStyle(treatment: installation == .current ? .soft : .accent))
                    .disabled(isSettingUp).fixedSize()
                    .accessibilityIdentifier("installAgentTools")
            }
            if pythonReady == false {
                HStack(spacing: 16) {
                    Image(systemName: "shippingbox").font(.system(size: 20)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Add Python to connect your agent").font(.system(size: 14, weight: .semibold))
                        Text("Python 3.10+ wasn’t found. Install it from python.org, then choose Check Python above.")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Link(destination: URL(string: "https://www.python.org/downloads/macos/")!) {
                        Label("Download Python", systemImage: "arrow.up.right")
                    }.buttonStyle(StudioButtonStyle()).fixedSize()
                }.padding(16).background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Label(pythonReady == true ? "Python is ready. Copy the instructions below to start directing." : installation == .missing ? "Install only when you need it. No administrator access or shell changes required." : "Tools stay in your user folder when you move the app. Updates are installed here on request.",
                      systemImage: pythonReady == true ? "link" : "info.circle")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            if installation != .missing {
                configuration
            } else {
                Text("Already connected through MCP? You can copy a director brief below without installing these tools.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
        .padding(24).background(Theme.field, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.75))
    }

    private func setUpAgentTools(install: Bool) {
        guard !isSettingUp else { return }
        isSettingUp = true
        Task {
            defer { isSettingUp = false }
            do {
                if install { try AgentGuide.installTools(); installation = AgentGuide.installation }
                pythonReady = await AgentGuide.checkPython()
                if pythonReady == true {
                    model.toasts.show(install ? "Agent tools installed" : "Python is ready", message: "Copy a director brief or connect your MCP client below.")
                }
            } catch { model.report(error) }
        }
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
                    .fixedSize(horizontal: false, vertical: true)
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
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
                        Button { model.copyForAgent(AgentGuide.mcpConfiguration, title: "MCP configuration copied") } label: {
                            Label("Copy MCP configuration", systemImage: "doc.on.doc")
                        }.buttonStyle(StudioButtonStyle()).disabled(installation != .current || pythonReady == false || isSettingUp)
                    }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Command line").font(.system(size: 14, weight: .semibold))
                        Text("Run this setup once per terminal session, then use showtime commands from any folder. Keep Showtime open while directing.")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
                        Text(AgentGuide.connectionCommand).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
                        Button { model.copyForAgent(AgentGuide.connectionCommand, title: "CLI command copied") } label: {
                            Label("Copy connection command", systemImage: "doc.on.doc")
                        }.buttonStyle(StudioButtonStyle()).disabled(installation != .current || pythonReady == false || isSettingUp)
                    }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                }.padding(.top, 18)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal").foregroundStyle(Theme.accent)
                    Text("Connection details").font(.system(size: 14, weight: .medium))
                    Text("MCP or CLI").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var exportLocation: some View {
        HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(Theme.muted)
                Text("Films are saved to Movies / Showtime").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Button("Open exports", action: model.revealExport).buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent)
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
