import AppKit
import ShowtimeCore

/// Native window operations for agents, including checks that need no global
/// Accessibility or Screen Recording permission. No window controls are redrawn.
@MainActor
enum StudioWindow {
    static let launchSize = CGSize(width: 1872, height: 1248)
    private static weak var placedWindow: NSWindow?
    private static var transition: FullScreenTransition?

    static func placeOnLaunch(_ window: NSWindow) {
        guard placedWindow !== window,
              let screen = window.screen ?? NSScreen.main else { return }
        placedWindow = window
        let visible = screen.visibleFrame
        let size = CGSize(width: min(launchSize.width, visible.width), height: min(launchSize.height, visible.height))
        let frame = CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                           width: size.width, height: size.height)
        // Place once. Theme, sidebar, and toolbar updates must never move or
        // resize a window the user has already arranged.
        window.setFrame(frame, display: false)
    }

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
        case "click":
            guard !window.isMiniaturized,
                  let x = request["x"] as? Double, let y = request["y"] as? Double,
                  x.isFinite, y.isFinite, (0..<window.frame.width).contains(x), (0..<window.frame.height).contains(y) else {
                throw ShowtimeError("Click coordinates must be inside the visible window, in AppKit points.")
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try click(at: CGPoint(x: x, y: y), count: 1, in: window)
        case "doubleClickTitlebar":
            guard !window.styleMask.contains(.fullScreen), !window.isMiniaturized else {
                throw ShowtimeError("Restore the window before double-clicking the titlebar.")
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Use the native gap between the wordmark and workspace tabs. The
            // top few pixels belong to the window's resize edge after full screen.
            // AppKit applies the user's double-click preference (Fill/Zoom/Minimize).
            let point = CGPoint(x: window.frame.width * 0.3, y: window.frame.height - 26)
            try click(at: point, count: 2, in: window)
        default:
            throw ShowtimeError("Window action must be zoom, minimize, restore, fullscreen, resize, click, or doubleClickTitlebar.")
        }
    }

    private static func click(at point: CGPoint, count: Int, in window: NSWindow) throws {
        let time = ProcessInfo.processInfo.systemUptime
        for index in 1...count {
            let delay = Double(index - 1) * 0.1
            guard let down = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: time + delay,
                                               windowNumber: window.windowNumber, context: nil, eventNumber: index * 2, clickCount: index, pressure: 1),
                  let up = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: time + delay + 0.02,
                                             windowNumber: window.windowNumber, context: nil, eventNumber: index * 2 + 1, clickCount: index, pressure: 0) else {
                throw ShowtimeError("Could not create a window mouse event.")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApp.postEvent(down, atStart: false)
                NSApp.postEvent(up, atStart: false)
            }
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
