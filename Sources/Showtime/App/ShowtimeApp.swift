import AppKit
import SwiftUI

@main
struct ShowtimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = StudioModel()

    var body: some Scene {
        Window("Showtime", id: "studio") {
            StudioView(model: model)
                .environment(\.colorScheme, .light)
                .frame(minWidth: 1120, minHeight: 760)
                .background(WindowAccessor { window in
                    model.window = window
                    StudioWindow.observe(window)
                    delegate.model = model
                    window.title = "Showtime — Your browser, directed."
                    // Keep the real AppKit titlebar and its native drag, double-click,
                    // traffic-light, tiling, and full-screen behavior.
                    window.titlebarSeparatorStyle = .none
                    window.isMovableByWindowBackground = false
                    window.backgroundColor = NSColor(Theme.surface)
                    window.acceptsMouseMovedEvents = true
                    window.tabbingMode = .disallowed
                })
                .task { delegate.model = model; model.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1560, height: 1040)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Film Script…", action: model.importScript).keyboardShortcut("o")
            }
            CommandMenu("Browser") {
                Button("Open Location") { model.addressEditing = true }.keyboardShortcut("l")
                Button("Reload Page") { if !model.isPlaying { model.browser.webView.reload() } }.keyboardShortcut("r")
                Button("Back") { if !model.isPlaying { model.browser.webView.goBack() } }.keyboardShortcut("[", modifiers: .command)
                Button("Forward") { if !model.isPlaying { model.browser.webView.goForward() } }.keyboardShortcut("]", modifiers: .command)
                Divider()
                Button("Open Orbit Demo") { model.navigate("showtime://demo") }
            }
            CommandMenu("Director") {
                Button("Rehearse") { model.playDemo(record: false) }.keyboardShortcut(.return, modifiers: .command).disabled(model.isBusy)
                Button("Record Film") { model.playDemo(record: true) }.keyboardShortcut(.return, modifiers: [.command, .shift]).disabled(model.isBusy)
                Button(model.isRecording ? "Finish Recording" : "Start Manual Recording") { model.toggleRecording() }
                    .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(model.isPlaying || model.isFinishing)
                Button("Stop Take") { model.director.cancel() }.keyboardShortcut(".", modifiers: .command).disabled(!model.isPlaying)
                Divider()
                Button("Show Exports", action: model.revealExport)
                Button("Agent Connection") { model.showConnection = true }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: StudioModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if !model.isBusy { model.stopServices(); return .terminateNow }
        Task { @MainActor in await model.shutdown(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { if let window = nsView.window { configure(window) } }
    }
}
