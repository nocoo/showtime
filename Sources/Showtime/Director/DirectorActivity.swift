import AppKit
import SwiftUI
import ShowtimeCore

enum DirectorActivitySource: String { case agent, local }
enum DirectorActivityPhase: String { case idle, working, completed, stopped, failed }

struct DirectorCue: Identifiable {
    var id: String
    var symbol: String
    var title: String
    var detail: String
    var tracks: [String] = []

    init(id: String, symbol: String, title: String, detail: String, tracks: [String] = []) {
        self.id = id; self.symbol = symbol; self.title = title; self.detail = detail; self.tracks = tracks
    }

    init(_ action: Action, id: String) {
        self.id = id
        symbol = action.activitySymbol
        title = action.label?.isEmpty == false ? action.label! : action.activityTitle
        detail = action.activityDetail
        tracks = action.action == .parallel ? (action.steps ?? []).filter { $0.action != .wait }.map(\.activitySymbol) : []
    }

    var json: [String: Any] { ["id": id, "symbol": symbol, "title": title, "detail": detail] }
}

struct DirectorActivityState {
    var phase: DirectorActivityPhase = .idle
    var source: DirectorActivitySource = .agent
    var name = "Your director is ready"
    var scene = "Live direction"
    var jobID: String?
    var current: DirectorCue?
    var next: DirectorCue?
    var recent: [DirectorCue] = []
    var completed = 0
    var total = 0
    var cueNumber = 0
    var output: URL?

    var progress: Double { total > 0 ? min(1, Double(completed) / Double(total)) : 0 }
    var json: [String: Any] {
        var result: [String: Any] = ["phase": phase.rawValue, "source": source.rawValue, "name": name, "scene": scene,
                                     "completed": completed, "total": total, "cue": cueNumber,
                                     "recent": recent.map(\.json)]
        if let jobID { result["job"] = jobID }
        if let current { result["current"] = current.json }
        if let next { result["next"] = next.json }
        if let output { result["output"] = output.path }
        return result
    }
}

/// Publish each cue boundary as one coherent state, so titles, icons, and
/// progress change together. Polling status does not create activity entries.
@MainActor
final class DirectorActivity: ObservableObject {
    @Published private(set) var state = DirectorActivityState()

    func begin(_ script: FilmScript, id: String, source: DirectorActivitySource, singleAction: Bool) {
        var next = DirectorActivityState()
        next.phase = .working
        next.source = source
        next.name = singleAction ? "Live direction" : script.name
        next.jobID = id
        next.total = script.steps.count
        if singleAction { next.recent = state.recent; next.scene = state.scene }
        next.current = DirectorCue(id: id + ":prepare", symbol: "sparkles", title: "Setting the scene", detail: "Preparing the next shot.")
        state = next
    }

    func beginCue(_ action: Action, index: Int, script: FilmScript, jobID: String) {
        var next = state
        next.current = DirectorCue(action, id: jobID + ":\(index)")
        next.cueNumber = index + 1
        if let marker = script.steps.prefix(index + 1).last(where: { $0.action == .marker }) {
            next.scene = marker.text ?? marker.label ?? "Current scene"
        }
        let upcoming = script.steps.enumerated().dropFirst(index + 1).first(where: { $0.element.action != .marker })
        next.next = upcoming.map { DirectorCue($0.element, id: jobID + ":\($0.offset)") }
        state = next
    }

    func completeCue(index: Int) {
        var next = state
        next.completed = index + 1
        if let cue = next.current {
            next.recent.append(cue)
            next.recent = Array(next.recent.suffix(4))
        }
        state = next
    }

    func finish(_ phase: DirectorActivityPhase, output: String?) {
        var next = state
        next.phase = phase
        next.next = nil
        next.output = output.map { URL(fileURLWithPath: $0) }
        state = next
    }

    func inspected() {
        guard state.phase != .working else { return }
        var next = state
        next.phase = .completed; next.source = .agent; next.name = "Live direction"
        next.jobID = nil; next.next = nil; next.output = nil
        next.current = DirectorCue(id: UUID().uuidString, symbol: "viewfinder", title: "Page inspected",
                                   detail: "Your agent has read the visible controls and is planning its next move.")
        next.recent = Array((next.recent + [next.current!]).suffix(4))
        next.completed = 1; next.total = 1; next.cueNumber = 1
        state = next
    }

    func recordingStarted() {
        var next = DirectorActivityState()
        next.phase = .working; next.name = "Live recording"
        next.current = DirectorCue(id: UUID().uuidString, symbol: "record.circle", title: "The camera is rolling",
                                   detail: "Mouse movement, camera work, and captions are being recorded.")
        state = next
    }
}

private extension Action {
    var activitySymbol: String {
        switch action {
        case .open: return "globe"
        case .metadata: return "pencil.line"
        case .move: return "cursorarrow.motionlines"
        case .click, .doubleClick: return "cursorarrow.click.2"
        case .drag: return "hand.draw"
        case .scroll: return "arrow.up.and.down"
        case .type, .key: return "keyboard"
        case .wait, .waitFor: return "pause"
        case .zoom: return "viewfinder"
        case .caption: return "text.bubble"
        case .cursor: return "cursorarrow"
        case .marker: return "film.stack"
        case .assert: return "checkmark.shield"
        case .screenshot: return "camera"
        case .evaluate: return "eye"
        case .parallel: return "sparkles"
        }
    }

    var activityTitle: String {
        switch action {
        case .open: return "Open the scene"
        case .metadata: return "Set the browser identity"
        case .move: return "Guide the viewer’s eye"
        case .click: return "Click the page"
        case .doubleClick: return "Double-click the page"
        case .drag: return "Move an element"
        case .scroll: return "Explore the page"
        case .type: return "Enter text"
        case .key: return "Use a keyboard shortcut"
        case .wait: return "Hold this frame"
        case .waitFor: return "Wait for the page"
        case .zoom: return (scale ?? 1) > 1 ? "Move in for a closer look" : "Return to the full picture"
        case .caption: return text?.isEmpty == false ? "Bring in the headline" : "Clear the headline"
        case .cursor: return "Style the cursor"
        case .marker: return text ?? "Start a new scene"
        case .assert: return "Check the result"
        case .screenshot: return "Capture a frame"
        case .evaluate: return "Read the page state"
        case .parallel: return "Compose the scene"
        }
    }

    var activityDetail: String {
        switch action {
        case .open: return title ?? URL(string: url ?? "")?.host ?? "Loading the website for this take."
        case .metadata: return title ?? "Updating the title and address shown in the film."
        case .caption: return text ?? "Making room for the next scene."
        case .zoom: return String(format: "Camera · %.2f×", scale ?? 1)
        case .wait: return String(format: "A %.1f second pause lets the moment land.", duration ?? 1)
        case .waitFor: return "Continuing as soon as the next element is ready."
        case .parallel: return "Moving the cursor, camera, and text together."
        case .assert: return "Confirming that the page responded as expected."
        case .evaluate: return "Understanding the page before the next action."
        case .screenshot: return "Saving the current film frame as a PNG."
        case .cursor: return "Preparing the pointer for the next shot."
        case .marker: return "A new chapter in your product story."
        case .key: return key.map { "Keyboard · " + $0.capitalized } ?? "Sending a native keyboard event."
        default:
            if let selector, selector.hasPrefix("#"), !selector.contains(" ") {
                return selector.dropFirst().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
            }
            return action == .type ? "Filling in the selected field." : "Interacting with the real webpage."
        }
    }
}

struct DirectorActivityView: View {
    @ObservedObject var model: StudioModel
    @ObservedObject var activity: DirectorActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var state: DirectorActivityState { activity.state }
    private var live: Bool { state.phase == .working || model.isRecording || model.isFinishing }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                Text(state.source == .agent ? "AI Director" : "Rehearsal").font(.system(size: 13, weight: .semibold))
                Text("·").foregroundStyle(Theme.muted)
                Text(state.scene).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                Spacer(minLength: 12)
                HStack(spacing: 6) {
                    Circle().fill(live ? Theme.accent : Theme.muted).frame(width: 5, height: 5)
                    Text(model.isFinishing ? "Saving film" : model.isRecording ? "Recording" : live ? "Directing live" : state.phase == .failed ? "Needs attention" : "Ready")
                        .font(.system(size: 12, weight: .medium))
                }.foregroundStyle(live ? Theme.accent : Theme.muted)
                if let output = state.output {
                    Button { NSWorkspace.shared.activateFileViewerSelecting([output]) } label: {
                        Label("View film", systemImage: "arrow.up.right")
                    }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent).padding(.leading, 12)
                } else if state.phase == .idle {
                    Button("Set up your agent") { model.mode = .director }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent).padding(.leading, 12)
                }
            }
            HStack(alignment: .center, spacing: 20) {
                HStack(spacing: 13) {
                    Image(systemName: currentSymbol).font(.system(size: 21, weight: .medium))
                        .foregroundStyle(state.phase == .failed ? Theme.danger : Theme.accent)
                        .frame(width: 48, height: 48)
                        .background(Theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                        .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(currentTitle).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                        Text(currentDetail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(2, reservesSpace: true)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentTransition(.opacity)
                    if let tracks = state.current?.tracks, !tracks.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(tracks.enumerated()), id: \.offset) { _, symbol in
                                Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Theme.accent)
                                    .frame(width: 26, height: 26).background(Theme.accent.opacity(0.07), in: Circle())
                            }
                        }
                    }
                }.frame(maxWidth: .infinity)
                Rectangle().fill(Theme.line).frame(width: 1, height: 42)
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.next == nil ? "AFTER THIS" : "UP NEXT").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Theme.muted)
                    Label(state.next?.title ?? (state.output != nil ? "Your film is ready to share" : "Your agent chooses the next move"),
                          systemImage: state.next?.symbol ?? "arrow.right")
                        .font(.system(size: 12, weight: .medium)).lineLimit(2, reservesSpace: true).foregroundStyle(Theme.ink)
                }.frame(width: 240, alignment: .leading).contentTransition(.opacity)
            }
            HStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.10))
                        Capsule().fill(Theme.accent).frame(width: geometry.size.width * state.progress)
                    }
                }.frame(height: 3)
                Text(state.total > 0 ? "\(state.completed) of \(state.total) cues complete" : "Waiting for your first direction")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted).monospacedDigit()
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state.current?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state.completed)
    }

    private var currentSymbol: String {
        if model.isFinishing { return "square.and.arrow.down" }
        if state.phase == .failed { return "exclamationmark.circle" }
        if state.output != nil { return "checkmark.circle" }
        return state.current?.symbol ?? "sparkles"
    }
    private var currentTitle: String {
        if model.isFinishing { return "Finishing your film" }
        if state.phase == .stopped { return "Take stopped" }
        if state.phase == .failed { return "This cue needs attention" }
        if state.output != nil { return "A good take. Ready to share." }
        return state.current?.title ?? "Your director is ready"
    }
    private var currentDetail: String {
        if model.isFinishing { return "Finalizing a playable MP4." }
        if let output = state.output { return output.lastPathComponent }
        if state.phase == .failed { return state.current?.title ?? "Review the notification, then ask your agent to continue." }
        return state.current?.detail ?? "Give your agent a brief, then watch the story unfold here."
    }
}
