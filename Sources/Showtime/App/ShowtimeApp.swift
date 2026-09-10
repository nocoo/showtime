import AppKit
import SwiftUI

@main
struct ShowtimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = StudioModel()

    var body: some Scene {
        Window("Showtime", id: "studio") {
            StudioView(model: model)
                .preferredColorScheme(model.appearance.colorScheme)
                .environment(\.colorScheme, model.appearance.colorScheme)
                .frame(minWidth: 1120, minHeight: 760)
                .background(WindowAccessor { window in
                    model.window = window
                    StudioWindow.observe(window)
                    delegate.model = model
                    window.title = "Showtime — Your browser, directed."
                    // Keep the real AppKit titlebar and its native drag, double-click,
                    // traffic-light, tiling, and full-screen behavior.
                    window.titlebarSeparatorStyle = .none
                    window.appearance = model.appearance.native
                    window.isMovableByWindowBackground = false
                    window.backgroundColor = NSColor(Theme.surface)
                    window.acceptsMouseMovedEvents = true
                    window.tabbingMode = .disallowed
                    StudioWindow.placeOnLaunch(window)
                })
                .task { delegate.model = model; model.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: StudioWindow.launchSize.width, height: StudioWindow.launchSize.height)
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
                Button("Rehearse Storyboard") { model.playStoryboard(record: false) }
                    .keyboardShortcut(.return, modifiers: .command).disabled(model.isBusy || model.currentScript == nil)
                Button(model.isRecording ? "Finish Recording" : "Record Current Webpage") { model.toggleRecording() }
                    .keyboardShortcut(.return, modifiers: [.command, .shift]).disabled(model.isPlaying || model.isFinishing || model.isPreparing)
                Button("Record Storyboard") { model.playStoryboard(record: true) }
                    .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(model.isBusy || model.currentScript == nil)
                Button("Stop Take") { model.director.cancel() }.keyboardShortcut(".", modifiers: .command).disabled(!model.isPlaying)
                Divider()
                Button("Show Exports", action: model.revealExport)
                Button("AI Director") { model.mode = .director }.disabled(model.isBusy)
                Button("Switch to \(model.appearance == .light ? "Dark" : "Light") Theme") {
                    model.appearance = model.appearance == .light ? .dark : .light
                }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: StudioModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let url = Bundle.main.url(forResource: "Showtime", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            // Rebuilt apps can retain an old Launch Services icon in the Dock.
            NSApp.applicationIconImage = icon
        }
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
