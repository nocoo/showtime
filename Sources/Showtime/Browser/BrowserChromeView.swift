import SwiftUI
import ShowtimeCore

/// A compact, neutral browser frame shared by the preview and exported film.
struct BrowserChromeView: View {
    @ObservedObject var model: StudioModel
    var exporting = false
    @State private var address = ""
    @FocusState private var focused: Bool
    private var palette: FilmChromePalette { FilmChromePalette(dark: model.canvas.browserTheme == "dark") }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                if let favicon = model.favicon {
                    Image(nsImage: favicon).resizable().interpolation(.high).scaledToFit()
                        .frame(width: 16, height: 16).accessibilityHidden(true)
                } else {
                    Image(systemName: "globe").font(.system(size: 14, weight: .regular))
                        .foregroundStyle(palette.muted).frame(width: 16, height: 16).accessibilityHidden(true)
                }
                Text(model.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.ink.opacity(0.88))
                    .lineLimit(1).truncationMode(.tail)
                    .accessibilityLabel("Page title")
            }.frame(minWidth: 110, idealWidth: 220, maxWidth: 264, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 9) {
                if focused && !exporting {
                    TextField("Enter a website address", text: $address)
                        .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(palette.ink).focused($focused)
                        .onSubmit { model.navigate(address); focused = false; model.addressEditing = false }
                        .onExitCommand { focused = false; model.addressEditing = false }
                        .accessibilityLabel("Website address")
                } else {
                    Button {
                        guard !model.isPlaying else { return }
                        address = model.actualURL
                        focused = true
                    } label: {
                        Text(model.displayURL.isEmpty ? "Enter a website address" : model.displayURL)
                            .font(.system(size: 12)).foregroundStyle(palette.ink.opacity(0.7))
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Website address")
                }
            }
            .padding(.horizontal, 12).frame(height: 30)
            .background(palette.field, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(palette.line, lineWidth: 0.7))
            .frame(minWidth: 200, maxWidth: 690)
            chromeButton(model.isLoading && !exporting ? "xmark" : "arrow.clockwise",
                         label: model.isLoading ? "Stop loading" : "Reload page · ⌘R", disabled: model.isPlaying && !exporting) {
                if model.isLoading { model.browser.webView.stopLoading() }
                else { model.browser.webView.reload() }
            }
        }
        .padding(.horizontal, 18).frame(height: CanvasSpec.chromeHeight)
        .background(palette.surface)
        .environment(\.colorScheme, model.canvas.browserTheme == "dark" ? .dark : .light)
        .overlay(alignment: .bottomLeading) {
            if model.isLoading && !exporting {
                GeometryReader { geometry in
                    Rectangle().fill(palette.accent.opacity(0.65))
                        .frame(width: geometry.size.width * model.loadingProgress, height: 2)
                }.frame(height: 2)
            }
        }
        .onChange(of: model.addressEditing) { _, editing in
            if editing && !exporting { address = model.actualURL; focused = true }
        }
        .onChange(of: focused) { _, value in if !value { model.addressEditing = false } }
    }

    private func chromeButton(_ symbol: String, label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.ink.opacity(disabled ? 0.2 : 0.65))
                .frame(width: 28, height: 34).contentShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).disabled(disabled).help(label).accessibilityLabel(label)
    }
}

// Film colors are independent of the surrounding Studio appearance.
private struct FilmChromePalette {
    let dark: Bool
    var ink: Color { color(dark ? 0xE7EDE8 : 0x253126) }
    var muted: Color { color(dark ? 0xA3AEA6 : 0x6F796F) }
    var accent: Color { color(dark ? 0xA5D58B : 0x4A8234) }
    var surface: Color { color(dark ? 0x242B28 : 0xFCFDFB) }
    var field: Color { color(dark ? 0x303934 : 0xF3F5F2) }
    var line: Color { (dark ? Color.white : Color.black).opacity(dark ? 0.08 : 0.055) }
    private func color(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}
