import AppKit
import QuartzCore
import WebKit
import ShowtimeCore

@MainActor
final class BrowserEngine: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    weak var owner: StudioModel?
    weak var surface: BrowserSurface?
    private var observations: [NSKeyValueObservation] = []
    private(set) var ready = false
    private var navigationError: Error?
    private var openRequest: UUID?
    private var snapshotTask: (id: UUID, rect: CGRect, pixelWidth: Double, task: Task<CGImage, Error>)?
    private var faviconTask: Task<Void, Never>?
    private var faviconNavigation = UUID()

    override init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: CanvasSpec().pageWidth, height: CanvasSpec().pageHeight), configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // Studio appearance is a workspace preference, not a change to the film.
        // Websites can still provide their own independent theme controls.
        webView.appearance = NSAppearance(named: .aqua)
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
        webView.underPageBackgroundColor = .white
        observations = [
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async { self?.owner?.actualTitle = view.title ?? "Untitled" }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async { self?.owner?.actualURL = view.url?.absoluteString ?? "" }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async { self?.owner?.isLoading = view.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async { self?.owner?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async { self?.owner?.canGoForward = view.canGoForward }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async { self?.owner?.loadingProgress = view.estimatedProgress }
            },
        ]
    }

    func open(_ input: String, title: String? = nil, displayURL: String? = nil, timeout: Double = 30) async throws {
        var address = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if address == "showtime://demo" { address = owner?.demoURL.absoluteString ?? address }
        if !address.contains("://"), !address.hasPrefix("about:") {
            address = (address.hasPrefix("localhost") || address.hasPrefix("127.0.0.1") || address.hasPrefix("[::1]") ? "http://" : "https://") + address
        }
        guard let url = URL(string: address), ["http", "https", "file", "about"].contains(url.scheme?.lowercased() ?? "") else {
            throw ShowtimeError("Enter an http://, https://, or file:// address.")
        }
        owner?.titleOverride = title ?? ""
        owner?.urlOverride = displayURL ?? ""
        owner?.errorMessage = nil
        // Fragment navigation may complete without a didFinish callback. Only
        // that same-document case can use URL + isLoading as its completion signal.
        var previous = webView.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
        var destination = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let fragmentNavigation = previous?.fragment != destination?.fragment || destination?.fragment != nil
        previous?.fragment = nil; destination?.fragment = nil
        let sameDocument = ready && fragmentNavigation && previous?.url == destination?.url
        let request = UUID()
        openRequest = request
        defer { if openRequest == request { openRequest = nil } }
        ready = false
        navigationError = nil
        if url.isFileURL { webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
        else { webView.load(URLRequest(url: url)) }
        let deadline = CACurrentMediaTime() + timeout
        while !ready {
            try Task.checkCancellation()
            guard openRequest == request else { throw CancellationError() }
            if let navigationError { throw navigationError }
            if CACurrentMediaTime() > deadline { webView.stopLoading(); throw ShowtimeError("Page load timed out: \(address)") }
            try await Task.sleep(for: .milliseconds(40))
            if sameDocument, !webView.isLoading, webView.url == url { ready = true }
        }
        guard openRequest == request else { throw CancellationError() }
        _ = try? await evaluate("document.fonts.ready.then(() => true)")
        try await Task.sleep(for: .milliseconds(120))
        guard openRequest == request else { throw CancellationError() }
    }

    func cancelOpen() { openRequest = nil }

    func stopLoading() {
        cancelOpen()
        webView.stopLoading()
        ready = webView.url != nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        ready = false
        navigationError = nil
        faviconNavigation = UUID()
        faviconTask?.cancel()
        owner?.favicon = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        owner?.actualTitle = webView.title ?? "Untitled"
        owner?.actualURL = webView.url?.absoluteString ?? ""
        loadFavicon()
    }

    private func loadFavicon() {
        guard let pageURL = webView.url else { return }
        let navigation = faviconNavigation
        faviconTask?.cancel()
        faviconTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let links = (try? await self.evaluate("""
            (() => {
              const links = [...document.querySelectorAll('link[rel]')]
                .filter(link => (!link.media || matchMedia(link.media).matches) &&
                  (link.rel.toLowerCase().split(/\\s+/).includes('icon') || link.rel.toLowerCase() === 'apple-touch-icon'));
              links.sort((a, b) => Number(a.rel.toLowerCase() === 'apple-touch-icon') - Number(b.rel.toLowerCase() === 'apple-touch-icon'));
              return [...new Set(links.map(link => link.href))].slice(0, 6);
            })()
            """)) as? [String] ?? []
            guard !Task.isCancelled, self.faviconNavigation == navigation else { return }
            let image = await SiteFavicon.load(links: links, pageURL: pageURL)
            guard !Task.isCancelled, self.faviconNavigation == navigation else { return }
            self.owner?.favicon = image
            self.faviconTask = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        navigationError = error
        owner?.report(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        owner?.report(ShowtimeError("The webpage process ended. Refresh the page to continue."))
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(["http", "https", "file", "about", "blob", "data"].contains(scheme) ? .allow : .cancel)
    }

    // Native dialogs remain visible to a human; automation fails explicitly instead of silently confirming them.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        if owner?.isPlaying == true {
            owner?.director.abort(ShowtimeError("Page opened an alert: \(message). Use an in-page dialog for a film."))
            completionHandler()
            return
        }
        let alert = NSAlert(); alert.messageText = message; alert.runModal(); completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        if owner?.isPlaying == true {
            owner?.director.abort(ShowtimeError("Page requested confirmation: \(message)."))
            completionHandler(false)
            return
        }
        let alert = NSAlert(); alert.messageText = message; alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func evaluate(_ expression: String) async throws -> Any? {
        try await webView.callAsyncJavaScript("return await (\(expression));", arguments: [:], in: nil, contentWorld: .page)
    }

    static func literal(_ value: String) -> String {
        String(decoding: try! JSONEncoder().encode(value), as: UTF8.self)
    }

    func target(selector: String?, x: Double?, y: Double?, scroll: Bool = true) async throws -> CGPoint {
        if let selector {
            let script = """
            (() => {
              const matches = [...document.querySelectorAll(\(Self.literal(selector)))];
              const el = matches.find(e => { const r=e.getBoundingClientRect(), s=getComputedStyle(e); return r.width>0 && r.height>0 && s.visibility!=='hidden' && s.display!=='none'; });
              if (!el) throw new Error('No visible element matches: ' + \(Self.literal(selector)));
              if (\(scroll ? "true" : "false")) el.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});
              const r=el.getBoundingClientRect();
              const left=Math.max(1,r.left), right=Math.min(innerWidth-1,r.right);
              const top=Math.max(1,r.top), bottom=Math.min(innerHeight-1,r.bottom);
              if (left>=right || top>=bottom) throw new Error('Element is outside the viewport');
              const x=(left+right)/2, y=(top+bottom)/2, hit=document.elementFromPoint(x,y);
              if (!hit || (!el.contains(hit) && !hit.contains(el))) throw new Error('Element is covered by another element: ' + \(Self.literal(selector)));
              if (el.disabled || el.getAttribute('aria-disabled')==='true') throw new Error('Element is disabled');
              return {x,y};
            })()
            """
            guard let result = try await evaluate(script) as? [String: Any], let x = result["x"] as? Double, let y = result["y"] as? Double else {
                throw ShowtimeError("Could not resolve \(selector).")
            }
            return CGPoint(x: x, y: y)
        }
        guard let x, let y, x >= 0, y >= 0, x < webView.bounds.width, y < webView.bounds.height else {
            throw ShowtimeError("Pointer coordinates are outside the webpage viewport (\(Int(webView.bounds.width)) × \(Int(webView.bounds.height))).")
        }
        return CGPoint(x: x, y: y)
    }

    func inspect() async throws -> Any {
        try await evaluate("""
        (() => {
          const escape=CSS.escape;
          function selector(el) {
            if (el.id) return '#'+escape(el.id);
            if (el.getAttribute('data-testid')) return '[data-testid='+JSON.stringify(el.getAttribute('data-testid'))+']';
            const parts=[]; let node=el;
            while(node && node.nodeType===1 && node!==document.body) {
              if(node.id){parts.unshift('#'+escape(node.id));break;}
              let part=node.tagName.toLowerCase();
              const siblings=[...node.parentElement.children].filter(x=>x.tagName===node.tagName);
              if(siblings.length>1) part+=':nth-of-type('+(siblings.indexOf(node)+1)+')';
              parts.unshift(part);node=node.parentElement;
            }
            return parts.join(' > ');
          }
          const elements=[...document.querySelectorAll('a,button,input,textarea,select,[role="button"],[contenteditable="true"],[data-testid]')]
            .filter(el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&r.bottom>0&&r.top<innerHeight;})
            .slice(0,250).map(el=>{const r=el.getBoundingClientRect();return {selector:selector(el),tag:el.tagName.toLowerCase(),role:el.getAttribute('role'),text:(el.getAttribute('aria-label')||el.innerText||el.getAttribute('placeholder')||'').trim().slice(0,140),value:el.type==='password'?undefined:el.value,disabled:!!el.disabled,rect:{x:r.x,y:r.y,width:r.width,height:r.height}};});
          return {title:document.title,url:location.href,viewport:{width:innerWidth,height:innerHeight},scroll:{x:scrollX,y:scrollY},elements};
        })()
        """) ?? [:]
    }

    func snapshot(pixelWidth: Double? = nil) async throws -> CGImage {
        guard webView.bounds.width > 0, webView.bounds.height > 0, let window = webView.window else {
            throw ShowtimeError("The browser window is not ready.")
        }
        let bounds = webView.bounds
        let pixelWidth = ceil(pixelWidth ?? owner?.snapshotPixelWidth() ?? bounds.width)
        if let pending = snapshotTask, pending.rect == bounds, pending.pixelWidth >= pixelWidth {
            return try await pending.task.value
        }
        // WKSnapshotConfiguration uses points; its bitmap includes the display's backing scale.
        let pointWidth = ceil(pixelWidth / max(1, window.backingScaleFactor))
        let id = UUID()
        let task = Task { @MainActor () throws -> CGImage in
            let config = WKSnapshotConfiguration()
            config.rect = bounds
            config.snapshotWidth = NSNumber(value: pointWidth)
            config.afterScreenUpdates = false
            let image = try await self.webView.takeSnapshot(configuration: config)
            var rect = CGRect(origin: .zero, size: image.size)
            guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { throw ShowtimeError("WebView returned an empty snapshot.") }
            return cg
        }
        snapshotTask = (id, bounds, pixelWidth, task)
        defer { if snapshotTask?.id == id { snapshotTask = nil } }
        return try await task.value
    }

    func cssPoint(fromWindow point: CGPoint) -> CGPoint {
        let p = webView.convert(point, from: nil)
        return CGPoint(x: p.x, y: webView.isFlipped ? p.y : webView.bounds.height - p.y)
    }

    private func nativePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: webView.isFlipped ? point.y : webView.bounds.height - point.y)
    }

    private func receiver(at point: CGPoint) -> NSView {
        let p = webView.convert(nativePoint(point), to: webView.superview)
        return webView.hitTest(p) ?? webView
    }

    func mouse(_ type: NSEvent.EventType, at point: CGPoint, clicks: Int = 1) throws {
        guard let window = webView.window else { throw ShowtimeError("Browser has no window.") }
        let location = webView.convert(nativePoint(point), to: nil)
        guard let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clicks,
                                            pressure: (type == .leftMouseDown || type == .leftMouseDragged) ? 1 : 0) else {
            throw ShowtimeError("Could not create a native mouse event.")
        }
        let target = receiver(at: point)
        switch type {
        case .leftMouseDown:
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeFirstResponder(target)
            target.mouseDown(with: event)
        case .leftMouseUp: target.mouseUp(with: event)
        case .leftMouseDragged: target.mouseDragged(with: event)
        default: target.mouseMoved(with: event)
        }
    }

    func scroll(at point: CGPoint, deltaX: Double, deltaY: Double, phase: CGScrollPhase? = nil) throws {
        guard deltaX != 0 || deltaY != 0 || phase != nil else { return }
        guard webView.window != nil,
              let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                               wheel1: Int32(-deltaY.rounded()), wheel2: Int32(-deltaX.rounded()), wheel3: 0) else {
            throw ShowtimeError("Could not create a native scroll event.")
        }
        let local = webView.convert(nativePoint(point), to: nil)
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        // Bridged wheel events have no associated NSWindow. We dispatch directly to
        // WebKit, which reads locationInWindow as window-local, so supply that basis.
        // CGEvent's top-left origin is flipped back by the NSEvent bridge.
        cg.location = CGPoint(x: local.x, y: mainHeight - local.y)
        cg.setIntegerValueField(.eventSourceUserData, value: 0x53484F57)
        cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        cg.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase?.rawValue ?? 0))
        guard let event = NSEvent(cgEvent: cg) else { throw ShowtimeError("Could not bridge a scroll event.") }
        receiver(at: point).scrollWheel(with: event)
    }

    func insertText(_ text: String) throws {
        guard let client = webView.window?.firstResponder as? NSTextInputClient else {
            throw ShowtimeError("No text field is focused. Click an input or provide a selector before typing.")
        }
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    func sendKey(_ key: String, modifiers: [String] = []) throws {
        guard let window = webView.window, let responder = window.firstResponder else { throw ShowtimeError("No focused browser view.") }
        var flags: NSEvent.ModifierFlags = []
        for modifier in modifiers {
            switch modifier { case "command": flags.insert(.command); case "shift": flags.insert(.shift)
            case "option": flags.insert(.option); case "control": flags.insert(.control); default: break }
        }
        let codes: [String: (UInt16, String)] = ["enter": (36, "\r"), "return": (36, "\r"), "tab": (48, "\t"),
            "escape": (53, "\u{1b}"), "backspace": (51, "\u{7f}"), "delete": (117, "\u{f728}"),
            "space": (49, " "), "left": (123, "\u{f702}"), "right": (124, "\u{f703}"),
            "down": (125, "\u{f701}"), "up": (126, "\u{f700}"), "a": (0, "a"), "c": (8, "c"),
            "v": (9, "v"), "x": (7, "x"), "z": (6, "z")]
        guard let (code, characters) = codes[key.lowercased()] else {
            throw ShowtimeError("Unsupported key: \(key). Use type for text; key supports enter, tab, escape, backspace, delete, space, arrows, and a/c/v/x/z.")
        }
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: window.windowNumber, context: nil, characters: characters,
                                              charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code) else { continue }
            if type == .keyDown {
                if flags.contains(.command), responder.performKeyEquivalent(with: event) { continue }
                responder.keyDown(with: event)
            } else { responder.keyUp(with: event) }
        }
    }
}
