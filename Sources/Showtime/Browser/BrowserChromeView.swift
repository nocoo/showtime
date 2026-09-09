import SwiftUI
import ShowtimeCore

/// A neutral browser frame. Every control has a real navigation action.
struct BrowserChromeView: View {
    @ObservedObject var model: StudioModel
    var exporting = false
    @State private var address = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 4) {
                chromeButton("chevron.left", label: "Back", disabled: !model.canGoBack || (model.isPlaying && !exporting)) {
                    model.browser.webView.goBack()
                }
                chromeButton("chevron.right", label: "Forward", disabled: !model.canGoForward || (model.isPlaying && !exporting)) {
                    model.browser.webView.goForward()
                }
            }
            Rectangle().fill(Theme.line).frame(width: 1, height: 24)
            Text(model.displayTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.88))
                .lineLimit(1).truncationMode(.tail)
                .frame(minWidth: 100, idealWidth: 260, maxWidth: 310, alignment: .leading)
                .accessibilityLabel("Page title")
            Spacer(minLength: 0)
            HStack(spacing: 11) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .regular)).foregroundStyle(Theme.muted)
                if focused && !exporting {
                    TextField("Enter a website address", text: $address)
                        .textFieldStyle(.plain).font(.system(size: 14)).focused($focused)
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
                            .font(.system(size: 14)).foregroundStyle(Theme.ink.opacity(0.65))
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Website address")
                }
            }
            .padding(.horizontal, 15).frame(height: 40)
            .background(Color(red: 0.954, green: 0.957, blue: 0.965), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line, lineWidth: 0.7))
            .frame(minWidth: 200, maxWidth: 690)
            chromeButton(model.isLoading && !exporting ? "xmark" : "arrow.clockwise",
                         label: model.isLoading ? "Stop loading" : "Reload page · ⌘R", disabled: model.isPlaying && !exporting) {
                if model.isLoading { model.browser.webView.stopLoading() }
                else { model.browser.webView.reload() }
            }
        }
        .padding(.horizontal, 22).frame(height: CanvasSpec.chromeHeight)
        .background(Color(red: 0.99, green: 0.99, blue: 0.995))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .overlay(alignment: .bottomLeading) {
            if model.isLoading && !exporting {
                GeometryReader { geometry in
                    Rectangle().fill(Theme.accent.opacity(0.65))
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
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink.opacity(disabled ? 0.2 : 0.65))
                .frame(width: 32, height: 38).contentShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).disabled(disabled).help(label).accessibilityLabel(label)
    }
}
