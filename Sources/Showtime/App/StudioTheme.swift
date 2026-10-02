import AppKit
import SwiftUI

enum StudioAppearance: String, CaseIterable {
    case light, dark
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
    var native: NSAppearance? { NSAppearance(named: self == .dark ? .darkAqua : .aqua) }
}

enum StudioMode: String { case studio, theater, director }

enum Theme {
    static let ink = adaptive("ink", light: 0x253126, dark: 0xE7EDE5)
    static let muted = adaptive("muted", light: 0x6F796F, dark: 0xA8B5A9)
    static let accentHex = "#4A8234"
    static let accent = adaptive("accent", light: 0x4A8234, dark: 0xA5D58B)
    static let onAccent = adaptive("onAccent", light: 0xFFFFFF, dark: 0x172513)
    static let line = adaptive("line", light: 0x273626, dark: 0xB9CCBD, lightAlpha: 0.08, darkAlpha: 0.14)
    static let surface = adaptive("surface", light: 0xF4F6F2, dark: 0x151D19)
    static let panel = adaptive("panel", light: 0xFFFFFF, dark: 0x1D2721)
    static let field = adaptive("field", light: 0xF8F9F7, dark: 0x253028)
    static let danger = adaptive("danger", light: 0xB74440, dark: 0xFF9E94)
    static let recording = Color(red: 0.77, green: 0.25, blue: 0.29)
    static let shadow = adaptive("shadow", light: 0x172111, dark: 0x000000, lightAlpha: 0.12, darkAlpha: 0.35)

    private static func adaptive(_ name: String, light: UInt32, dark: UInt32,
                                 lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Showtime.\(name)")) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let value = isDark ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255,
                           alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
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
        case .soft: return hovering ? Theme.field : Theme.panel
        case .accent: return Theme.accent
        case .recording: return Theme.recording
        }
    }

    var body: some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(treatment == .accent ? Theme.onAccent : (isProminent ? .white : Theme.ink))
            .padding(.horizontal, 13).frame(height: 38)
            .background(fill, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(treatment == .soft ? Theme.line : .clear))
            .shadow(color: treatment == .soft ? Theme.shadow.opacity(0.25) : .clear, radius: 1.5, y: 1)
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
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line, lineWidth: 0.75))
    }
}

struct StudioSegmentedPicker<Value: Hashable>: View {
    let title: String
    let choices: [(Value, String)]
    @Binding var selection: Value
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 2) {
            ForEach(choices, id: \.0) { value, label in
                Button { selection = value } label: {
                    Text(label).font(.system(size: 12, weight: selection == value ? .semibold : .medium))
                        .foregroundStyle(selection == value ? Theme.onAccent : Theme.muted)
                        .frame(maxWidth: .infinity).frame(height: 32)
                        .background(selection == value ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? [.isSelected] : [])
                    .accessibilityLabel("\(title): \(label)")
            }
        }.padding(3).background(Theme.field, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 0.75))
            .opacity(isEnabled ? 1 : 0.5).accessibilityElement(children: .contain).accessibilityLabel(title)
    }
}

struct StudioMenu: View {
    let title: String
    let selection: String
    let options: [(title: String, action: () -> Void)]
    @StateObject private var anchor = MenuAnchor()
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: openMenu) {
            HStack(spacing: 6) {
                Text(selection).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .medium))
            }.font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 11).frame(maxWidth: .infinity, alignment: .leading).frame(height: 38)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(hovering ? Theme.ink.opacity(0.18) : Theme.line, lineWidth: 0.75))
        }.buttonStyle(.plain).background(MenuAnchorView(anchor: anchor)).onHover { hovering = $0 }
            .opacity(isEnabled ? 1 : 0.5).accessibilityLabel(title).accessibilityValue(selection)
    }

    private func openMenu() {
        guard let view = anchor.view else { return }
        let menu = NSMenu()
        let target = MenuTarget(actions: options.map(\.action))
        for (index, option) in options.enumerated() {
            let item = NSMenuItem(title: option.title, action: #selector(MenuTarget.choose(_:)), keyEquivalent: "")
            item.tag = index; item.target = target
            item.state = option.title == selection ? .on : .off
            menu.addItem(item)
        }
        menu.minimumWidth = view.bounds.width
        // Keep a genuine macOS menu, anchored to the full-width Studio control.
        _ = withExtendedLifetime(target) { menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view) }
    }
}

private final class MenuAnchor: ObservableObject { weak var view: NSView? }
private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor
    func makeNSView(context: Context) -> NSView {
        let view = NSView(); anchor.view = view; return view
    }
    func updateNSView(_ view: NSView, context: Context) { anchor.view = view }
}
private final class MenuTarget: NSObject {
    let actions: [() -> Void]
    init(actions: [() -> Void]) { self.actions = actions }
    @objc func choose(_ item: NSMenuItem) { actions[item.tag]() }
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
