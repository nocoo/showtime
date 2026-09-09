import SwiftUI

enum Theme {
    static let ink = Color(red: 37 / 255, green: 49 / 255, blue: 38 / 255)
    static let muted = Color(red: 111 / 255, green: 121 / 255, blue: 111 / 255)
    static let accentHex = "#4A8234"
    static let accent = Color(red: 74 / 255, green: 130 / 255, blue: 52 / 255)
    static let sprout = Color(red: 207 / 255, green: 232 / 255, blue: 181 / 255)
    static let line = Color(red: 39 / 255, green: 54 / 255, blue: 38 / 255).opacity(0.08)
    static let surface = Color(red: 244 / 255, green: 246 / 255, blue: 242 / 255)
    static let field = Color(red: 248 / 255, green: 249 / 255, blue: 247 / 255)
}

/// Shared, quiet controls for the studio. The film has its own browser chrome.
struct StudioButtonStyle: ButtonStyle {
    enum Treatment { case plain, soft, accent, recording }
    var treatment: Treatment = .soft
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        StudioButtonSurface(configuration: configuration, treatment: treatment, isEnabled: isEnabled)
    }
}

private struct StudioButtonSurface: View {
    let configuration: ButtonStyleConfiguration
    let treatment: StudioButtonStyle.Treatment
    let isEnabled: Bool
    @State private var hovering = false

    private var isProminent: Bool { treatment == .accent || treatment == .recording }
    private var fill: Color {
        switch treatment {
        case .plain: return hovering ? Theme.ink.opacity(0.055) : .clear
        case .soft: return hovering ? Theme.field : .white
        case .accent: return Theme.accent
        case .recording: return Color(red: 0.77, green: 0.25, blue: 0.29)
        }
    }

    var body: some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isProminent ? .white : Theme.ink)
            .padding(.horizontal, 13).frame(height: 38)
            .background(fill, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(treatment == .soft ? Theme.line : .clear))
            .brightness(configuration.isPressed ? -0.035 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .onHover { hovering = $0 }
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Theme.ink)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line, lineWidth: 0.75))
    }
}

extension ToolbarContent {
    /// Our controls already supply their own surfaces; opt out of Tahoe's extra
    /// group capsules while retaining the system's toolbar and window controls.
    @ToolbarContentBuilder
    func hideSharedBackground() -> some ToolbarContent {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { sharedBackgroundVisibility(.hidden) }
        else { self }
        #else
        self
        #endif
    }
}
