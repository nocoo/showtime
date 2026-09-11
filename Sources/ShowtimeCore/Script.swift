import Foundation
import CoreGraphics

public struct ShowtimeError: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    public var foundation: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return v
        case .number(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map(\.foundation)
        case .object(let v): return v.mapValues(\.foundation)
        }
    }
}

public struct CanvasSpec: Codable, Equatable, Sendable {
    public var width: Int = 1920
    public var height: Int = 1080
    public var inset: Double = 32
    public var backdrop: String = "mist"
    public var glow: Bool = false
    /// Soft falloff beyond the bright core, relative to the Canvas short edge.
    public var glowRadius: Double = 0.75
    /// Bright core diameter, relative to the Canvas short edge.
    public var glowSize: Double = 0.3
    public var browserTheme: String = "light"
    public var frame: DeviceFrame = .none
    /// Screen width in Canvas pixels, excluding hardware. nil keeps automatic fitting.
    public var contentWidth: Int?
    public static let chromeHeight: Double = 56
    public static let backdrops = ["mist", "pearl", "midnight", "silver", "cloud", "sky", "mint", "rose", "butter"]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? 1920
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? 1080
        inset = try c.decodeIfPresent(Double.self, forKey: .inset) ?? 32
        backdrop = try c.decodeIfPresent(String.self, forKey: .backdrop) ?? "mist"
        glow = try c.decodeIfPresent(Bool.self, forKey: .glow) ?? false
        glowRadius = try c.decodeIfPresent(Double.self, forKey: .glowRadius) ?? 0.75
        glowSize = try c.decodeIfPresent(Double.self, forKey: .glowSize) ?? 0.3
        browserTheme = try c.decodeIfPresent(String.self, forKey: .browserTheme) ?? "light"
        frame = try c.decodeIfPresent(DeviceFrame.self, forKey: .frame) ?? .none
        contentWidth = try c.decodeIfPresent(Int.self, forKey: .contentWidth)
    }

    public var layout: FrameLayout { FrameLayout(canvas: self) }
    public var pageWidth: Double { layout.canvasPage.width }
    public var pageHeight: Double { layout.canvasPage.height }
    public var maximumInset: Double {
        max(0, min(160, Double(width - (frame == .none ? 600 : 320)) / 2,
                   (Double(height) - (frame == .none ? 300 + Self.chromeHeight : 320)) / 2))
    }
    public var maximumContentWidth: Int {
        var available = self
        available.contentWidth = nil
        available.inset = 0
        return Int(available.layout.canvasScreen.width.rounded(.down))
    }

    public func validate() throws {
        guard (800...3840).contains(width), (500...2160).contains(height) else {
            throw ShowtimeError("Canvas must be between 800 × 500 and 3840 × 2160 CSS pixels.")
        }
        guard inset.isFinite, (0...maximumInset).contains(inset) else {
            throw ShowtimeError("Canvas inset leaves too little room for the browser.")
        }
        if let contentWidth, !(1...maximumContentWidth).contains(contentWidth) {
            throw ShowtimeError("Content width must be between 1 and \(maximumContentWidth) px for \(frame.title) on a \(width) × \(height) Canvas. Use Auto to fit the frame automatically.")
        }
        guard Self.backdrops.contains(backdrop) else {
            throw ShowtimeError("Unknown backdrop. Use \(Self.backdrops.joined(separator: ", ")).")
        }
        guard glowRadius.isFinite, (0.1...1.5).contains(glowRadius), glowSize.isFinite, (0...1).contains(glowSize) else {
            throw ShowtimeError("Glow radius must be 0.1–1.5 and core size 0–1, relative to the Canvas short edge.")
        }
        guard ["light", "dark"].contains(browserTheme) else {
            throw ShowtimeError("Browser frame theme must be light or dark.")
        }
    }
}

public struct RecordingSpec: Codable, Equatable, Sendable {
    public var output: String?
    public var width: Int = 1920
    public var height: Int = 1080
    public var fps: Int = 30

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        output = try c.decodeIfPresent(String.self, forKey: .output)
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? 1920
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? 1080
        fps = try c.decodeIfPresent(Int.self, forKey: .fps) ?? 30
    }

    public func validate(canvas: CanvasSpec) throws {
        guard (640...3840).contains(width), (360...2160).contains(height), width % 2 == 0, height % 2 == 0 else {
            throw ShowtimeError("H.264 output needs even dimensions between 640 × 360 and 3840 × 2160.")
        }
        guard [24, 30, 60].contains(fps) else { throw ShowtimeError("Frame rate must be 24, 30, or 60.") }
        let outputRatio = Double(width) / Double(height)
        let canvasRatio = Double(canvas.width) / Double(canvas.height)
        guard abs(outputRatio - canvasRatio) < 0.005 else {
            throw ShowtimeError("Recording and canvas aspect ratios must match; the browser will not be stretched.")
        }
        if let output, URL(fileURLWithPath: output).pathExtension.lowercased() != "mp4" {
            throw ShowtimeError("Recording output must have an .mp4 extension.")
        }
    }

    /// Find an encodable size close to the requested long edge while preserving
    /// the canvas ratio. Searching even rows also handles odd/custom canvases
    /// and portrait output without rounding outside the encoder's limits.
    public func fitted(to canvas: CanvasSpec, longEdge: Int? = nil) throws -> RecordingSpec {
        try canvas.validate()
        // A theme or frame-rate edit must preserve a valid custom resolution.
        if longEdge == nil, (try? validate(canvas: canvas)) != nil { return self }
        let preferred = min(3840, max(640, longEdge ?? max(width, height)))
        let ratio = Double(canvas.width) / Double(canvas.height)
        var best: (width: Int, height: Int, distance: Int, error: Double)?
        for h in stride(from: 360, through: 2160, by: 2) {
            let w = min(3840, max(640, Int((Double(h) * ratio / 2).rounded()) * 2))
            let error = abs(Double(w) / Double(h) - ratio)
            guard error < 0.005 else { continue }
            let distance = abs(max(w, h) - preferred)
            if best == nil || distance < best!.distance || (distance == best!.distance && error < best!.error) {
                best = (w, h, distance, error)
            }
        }
        guard let best else { throw ShowtimeError("This canvas has no compatible H.264 output size.") }
        var result = self
        result.width = best.width
        result.height = best.height
        try result.validate(canvas: canvas)
        return result
    }
}

public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case open, metadata, move, click, doubleClick, drag, scroll, type, key
    case wait, waitFor, zoom, camera, caption, cursor, marker, assert, screenshot, evaluate, parallel
}

public struct Action: Codable, Sendable {
    public var action: ActionKind
    public var id: String?
    public var label: String?
    public var url: String?
    public var title: String?
    public var displayURL: String?
    public var selector: String?
    public var toSelector: String?
    public var x: Double?
    public var y: Double?
    public var toX: Double?
    public var toY: Double?
    public var duration: Double?
    public var timeout: Double?
    public var delay: Double?
    public var text: String?
    public var subtitle: String?
    public var eyebrow: String?
    public var style: String?
    public var position: String?
    public var color: String?
    public var size: Double?
    public var visible: Bool?
    public var image: String?
    public var hotspotX: Double?
    public var hotspotY: Double?
    public var clickEffect: Bool?
    public var scale: Double?
    public var offsetX: Double?
    public var offsetY: Double?
    public var rotation: Double?
    public var flipX: Bool?
    public var flipY: Bool?
    public var deltaX: Double?
    public var deltaY: Double?
    public var key: String?
    public var modifiers: [String]?
    public var clear: Bool?
    public var script: String?
    public var equals: JSONValue?
    public var output: String?
    public var easing: String?
    public var arc: Double?
    public var steps: [Action]?

    public init(_ action: ActionKind) { self.action = action }

    public var displayLabel: String {
        if let label { return label }
        switch action {
        case .open: return "Open the scene"
        case .metadata: return "Set browser identity"
        case .move: return "Guide the cursor"
        case .click, .doubleClick: return "Click \(selector ?? "on page")"
        case .type: return "Type \(text.map { String($0.prefix(26)) } ?? "text")"
        case .zoom, .camera: return "Move the camera"
        case .caption: return text ?? "Clear caption"
        case .marker: return text ?? "Scene"
        case .wait: return "Let the scene breathe"
        default: return action.rawValue.prefix(1).uppercased() + action.rawValue.dropFirst()
        }
    }

    public func validate(depth: Int = 0) throws {
        guard depth < 5 else { throw ShowtimeError("Parallel groups cannot nest more than four levels.") }
        let numbers = [x, y, toX, toY, duration, timeout, delay, size, scale, offsetX, offsetY, rotation, deltaX, deltaY, arc, hotspotX, hotspotY].compactMap { $0 }
        guard numbers.allSatisfy(\.isFinite) else { throw ShowtimeError("Action values must be finite numbers.") }
        if let id, id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || id.count > 80 || Double(id.trimmingCharacters(in: .whitespacesAndNewlines)) != nil {
            throw ShowtimeError("Step IDs must be nonempty, nonnumeric strings of at most 80 characters.")
        }
        if let duration, !(0...300).contains(duration) { throw ShowtimeError("Duration must be between 0 and 300 seconds.") }
        if let timeout, !(0.1...120).contains(timeout) { throw ShowtimeError("Timeout must be between 0.1 and 120 seconds.") }
        if let delay, !(0...2).contains(delay) { throw ShowtimeError("Typing delay must be between 0 and 2 seconds.") }
        if let scale, !(0.25...4).contains(scale) { throw ShowtimeError("Camera scale must be between 0.25 and 4.") }
        if let rotation, !(-360...360).contains(rotation) { throw ShowtimeError("Camera rotation must be between -360 and 360 degrees.") }
        if [offsetX, offsetY].compactMap({ $0 }).contains(where: { abs($0) > 8192 }) { throw ShowtimeError("Camera offsets must be within 8192 CSS pixels.") }
        if let size, !(8...96).contains(size) { throw ShowtimeError("Cursor size must be between 8 and 96.") }
        if [hotspotX, hotspotY].compactMap({ $0 }).contains(where: { !(0...1).contains($0) }) {
            throw ShowtimeError("Custom cursor hotspots must be fractions between 0 and 1.")
        }
        if let easing, !["linear", "smooth", "cinematic"].contains(easing) { throw ShowtimeError("Unknown easing: \(easing).") }
        if let modifiers, !modifiers.allSatisfy({ ["command", "shift", "option", "control"].contains($0) }) {
            throw ShowtimeError("Key modifiers: command, shift, option, control.")
        }
        if let color {
            let hex = color.hasPrefix("#") ? String(color.dropFirst()) : color
            guard hex.count == 6, UInt64(hex, radix: 16) != nil else { throw ShowtimeError("Colors must be six-digit hex strings.") }
        }
        let hasPoint = x != nil && y != nil
        guard (x == nil) == (y == nil), (toX == nil) == (toY == nil) else {
            throw ShowtimeError("Coordinates need both x and y.")
        }
        switch action {
        case .open:
            guard let url, !url.isEmpty else { throw ShowtimeError("open requires url.") }
        case .move, .click, .doubleClick, .drag:
            guard selector != nil || hasPoint else { throw ShowtimeError("\(action.rawValue) requires a selector or x/y.") }
            if action == .drag, toSelector == nil, toX == nil { throw ShowtimeError("drag requires toSelector or toX/toY.") }
        case .type:
            guard let text, text.count <= 100_000 else { throw ShowtimeError("type requires text (maximum 100,000 characters).") }
        case .key:
            guard let key, !key.isEmpty else { throw ShowtimeError("key requires a key name.") }
        case .waitFor:
            guard selector != nil || script != nil else { throw ShowtimeError("waitFor requires selector or script.") }
        case .assert, .evaluate:
            guard let script, !script.isEmpty else { throw ShowtimeError("\(action.rawValue) requires a JavaScript expression.") }
        case .screenshot:
            guard let output, URL(fileURLWithPath: output).pathExtension.lowercased() == "png" else {
                throw ShowtimeError("screenshot requires an output path ending in .png.")
            }
        case .cursor:
            if let style, !["arrow", "ring", "dot", "hand", "spotlight", "custom"].contains(style) { throw ShowtimeError("Unknown cursor style.") }
            if style == "custom", image == nil { throw ShowtimeError("A custom cursor requires an image path.") }
        case .caption:
            if let text, text.count > 400 { throw ShowtimeError("Captions are limited to 400 characters.") }
            if let position, !["bottom", "center", "top"].contains(position) { throw ShowtimeError("Caption position: bottom, center, or top.") }
            if let style, !["glass", "minimal", "title"].contains(style) { throw ShowtimeError("Caption style: glass, minimal, or title.") }
        case .parallel:
            guard let steps, !steps.isEmpty, steps.count <= 8 else { throw ShowtimeError("parallel needs 1–8 visual steps.") }
            let allowed: Set<ActionKind> = [.move, .zoom, .camera, .caption, .wait]
            var tracks = Set<ActionKind>()
            for step in steps {
                guard allowed.contains(step.action) else { throw ShowtimeError("parallel supports move, camera, zoom, caption, and wait.") }
                let track: ActionKind = step.action == .zoom ? .camera : step.action
                if track != .wait, !tracks.insert(track).inserted { throw ShowtimeError("A parallel group can only animate each track once.") }
                try step.validate(depth: depth + 1)
            }
        default: break
        }
    }
}

public struct FilmScript: Codable, Sendable {
    public var version: Int = 1
    public var name: String = "Untitled film"
    public var canvas: CanvasSpec?
    public var recording: RecordingSpec?
    /// Explicit preparation runs before every selected range, outside the recording.
    public var setup: [Action] = []
    public var steps: [Action]

    public init(name: String, steps: [Action]) { self.name = name; self.steps = steps }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled film"
        canvas = try c.decodeIfPresent(CanvasSpec.self, forKey: .canvas)
        recording = try c.decodeIfPresent(RecordingSpec.self, forKey: .recording)
        setup = try c.decodeIfPresent([Action].self, forKey: .setup) ?? []
        steps = try c.decode([Action].self, forKey: .steps)
    }

    public func validate(defaultCanvas: CanvasSpec = CanvasSpec()) throws {
        guard version == 1 else { throw ShowtimeError("Unsupported script version \(version). Expected 1.") }
        guard !steps.isEmpty, steps.count + setup.count <= 1000 else { throw ShowtimeError("A film needs at least one step and at most 1000 steps including setup.") }
        let c = canvas ?? defaultCanvas
        try c.validate()
        try recording?.validate(canvas: c)
        var ids = Set<String>()
        for (section, actions) in [("Setup", setup), ("Step", steps)] {
            for (index, step) in actions.enumerated() {
                do {
                    try step.validate()
                    if let id = step.id, !ids.insert(id).inserted { throw ShowtimeError("Duplicate step ID: \(id).") }
                } catch { throw ShowtimeError("\(section) \(index + 1) (\(step.action.rawValue)): \(error.localizedDescription)") }
            }
        }
    }
}

public enum Motion {
    public static func ease(_ t: Double, curve: String = "cinematic") -> Double {
        let p = min(1, max(0, t))
        switch curve {
        case "linear": return p
        case "smooth": return p * p * (3 - 2 * p)
        default: return p * p * p * (p * (p * 6 - 15) + 10)
        }
    }

    public static func cameraPoint(x: Double, y: Double, focusX: Double, focusY: Double, scale: Double) -> (Double, Double) {
        ((x - focusX) * scale + focusX, (y - focusY) * scale + focusY)
    }
}
