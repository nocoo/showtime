import AppKit
import SwiftUI

struct StudioToast: Identifiable {
    enum Kind { case success, error }
    let id = UUID()
    var title: String
    var message: String
    var kind: Kind
    var exportURL: URL?
}

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var current: StudioToast?
    private var dismissal: Task<Void, Never>?
    private var deadline: Date?
    private var remaining: Double = 0
    private var hovering = false

    func show(_ title: String, message: String, kind: StudioToast.Kind = .success, exportURL: URL? = nil) {
        dismissal?.cancel()
        deadline = nil
        current = StudioToast(title: title, message: message, kind: kind, exportURL: exportURL)
        remaining = kind == .error ? 8 : 4
        scheduleDismissal()
    }

    func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        deadline = nil
        hovering = false
        current = nil
    }

    func pause() {
        hovering = true
        if let deadline { remaining = max(0.2, deadline.timeIntervalSinceNow) }
        dismissal?.cancel()
        deadline = nil
    }

    func resume() {
        hovering = false
        scheduleDismissal()
    }

    private func scheduleDismissal() {
        guard !hovering, let id = current?.id else { return }
        dismissal?.cancel()
        deadline = Date().addingTimeInterval(remaining)
        dismissal = Task { @MainActor [weak self, remaining] in
            do { try await Task.sleep(for: .seconds(remaining)) }
            catch { return }
            guard self?.current?.id == id else { return }
            self?.dismiss()
        }
    }
}

struct StudioToastOverlay: View {
    @ObservedObject var center: ToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let toast = center.current {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: toast.kind == .error ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(toast.kind == .error ? Theme.danger : Theme.accent)
                        .frame(width: 32, height: 32)
                        .background((toast.kind == .error ? Theme.danger : Theme.accent).opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(toast.title).font(.system(size: 14, weight: .semibold))
                        Text(toast.message).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            .lineLimit(4).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        if let url = toast.exportURL {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.accent).padding(.top, 3)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: center.dismiss) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.muted).frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Dismiss notification")
                }
                .padding(16).frame(width: 380, alignment: .leading)
                .foregroundStyle(Theme.ink)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line))
                .shadow(color: Theme.shadow, radius: 20, x: 0, y: 8)
                .accessibilityElement(children: .contain).accessibilityLabel(toast.title + ". " + toast.message)
                .id(toast.id)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .onHover { hovering in if hovering { center.pause() } else { center.resume() } }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: center.current?.id)
    }
}
