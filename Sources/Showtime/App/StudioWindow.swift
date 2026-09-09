import AppKit
import ShowtimeCore

/// Native window operations for agents, including checks that need no global
/// Accessibility or Screen Recording permission. No window controls are redrawn.
@MainActor
enum StudioWindow {
    private static var transition: FullScreenTransition?

    static func observe(_ window: NSWindow) {
        guard transition?.window !== window else { return }
        transition = FullScreenTransition(window: window)
    }

    static func state(_ window: NSWindow) -> [String: Any] {
        observe(window)
        var buttons: [String: Any] = [:]
        for (name, type) in [("close", NSWindow.ButtonType.closeButton), ("minimize", .miniaturizeButton), ("zoom", .zoomButton)] {
            guard let button = window.standardWindowButton(type) else { continue }
            buttons[name] = ["enabled": button.isEnabled, "visible": !button.isHiddenOrHasHiddenAncestor,
                             "frame": rectangle(button.convert(button.bounds, to: nil))]
        }
        return ["frame": rectangle(window.frame), "screen": rectangle(window.screen?.visibleFrame ?? window.frame),
                "minimumSize": ["width": window.minSize.width, "height": window.minSize.height],
                "contentLayout": rectangle(window.contentLayoutRect), "zoomed": window.isZoomed,
                "minimized": window.isMiniaturized, "fullscreen": window.styleMask.contains(.fullScreen),
                "transitioning": transition?.isActive ?? false,
                "visible": window.isVisible, "trafficLights": buttons]
    }

    static func perform(_ request: [String: Any], on window: NSWindow) throws {
        guard let action = request["action"] as? String else { throw ShowtimeError("A window action is required.") }
        observe(window)
        guard transition?.isActive != true else {
            throw ShowtimeError("Wait for the native full-screen animation to finish before changing the window.")
        }
        switch action {
        case "zoom":
            guard !window.styleMask.contains(.fullScreen), !window.isMiniaturized else {
                throw ShowtimeError("Restore the window before zooming it.")
            }
            window.performZoom(nil)
        case "minimize":
            guard !window.styleMask.contains(.fullScreen) else { throw ShowtimeError("Exit full screen before minimizing the window.") }
            window.standardWindowButton(.miniaturizeButton)?.performClick(nil)
        case "restore":
            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized { window.deminiaturize(nil) }
            if window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
            else if window.isZoomed { window.performZoom(nil) }
            window.makeKeyAndOrderFront(nil)
        case "fullscreen":
            guard !window.isMiniaturized else { throw ShowtimeError("Restore the window before entering full screen.") }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.toggleFullScreen(nil)
        case "resize":
            guard !window.styleMask.contains(.fullScreen), !window.isMiniaturized else {
                throw ShowtimeError("Restore the window before resizing it.")
            }
            guard let width = request["width"] as? Double, let height = request["height"] as? Double,
                  width.isFinite, height.isFinite, (320...8192).contains(width), (240...8192).contains(height) else {
                throw ShowtimeError("Window width and height must be finite numbers between 320 × 240 and 8192 × 8192.")
            }
            let screen = window.screen?.visibleFrame ?? window.frame
            let size = CGSize(width: max(window.minSize.width, min(width, screen.width)),
                              height: max(window.minSize.height, min(height, screen.height)))
            var frame = window.frame
            frame.origin.y += frame.height - size.height
            frame.size = size
            frame.origin.x = max(screen.minX, min(frame.minX, screen.maxX - size.width))
            frame.origin.y = max(screen.minY, min(frame.minY, screen.maxY - size.height))
            window.setFrame(frame, display: true)
        case "doubleClickTitlebar":
            guard !window.styleMask.contains(.fullScreen), !window.isMiniaturized else {
                throw ShowtimeError("Restore the window before double-clicking the titlebar.")
            }
            // This lands in the native draggable strip above toolbar items. Let
            // AppKit apply the user's double-click preference (Fill/Zoom/Minimize).
            let point = CGPoint(x: window.frame.width / 2, y: window.frame.height - 4)
            let time = ProcessInfo.processInfo.systemUptime
            guard let down = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: time,
                                               windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 2, pressure: 1),
                  let up = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: time + 0.02,
                                             windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 2, pressure: 0) else {
                throw ShowtimeError("Could not create a titlebar mouse event.")
            }
            NSApp.postEvent(down, atStart: false)
            NSApp.postEvent(up, atStart: false)
        default:
            throw ShowtimeError("Window action must be zoom, minimize, restore, fullscreen, resize, or doubleClickTitlebar.")
        }
    }

    private static func rectangle(_ frame: CGRect) -> [String: Double] {
        ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
    }
}

/// The style mask changes at the start of a full-screen animation. AppKit's
/// notifications tell agents when it can actually accept the next operation.
/// Observe the window without replacing SwiftUI's native window delegate.
@MainActor
private final class FullScreenTransition: NSObject {
    weak var window: NSWindow?
    private(set) var isActive = false

    init(window: NSWindow) {
        self.window = window
        super.init()
        let center = NotificationCenter.default
        for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification] {
            center.addObserver(self, selector: #selector(fullScreenWillChange(_:)), name: name, object: window)
        }
        for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
            center.addObserver(self, selector: #selector(fullScreenDidChange(_:)), name: name, object: window)
        }
    }

    @objc private func fullScreenWillChange(_ notification: Notification) { isActive = true }
    @objc private func fullScreenDidChange(_ notification: Notification) { isActive = false }

    deinit { NotificationCenter.default.removeObserver(self) }
}
