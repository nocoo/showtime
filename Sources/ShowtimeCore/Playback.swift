import Foundation
import CoreGraphics

public enum PlaybackMode: String, Codable, Sendable {
    case design, rehearse, record
}

/// One-based inclusive boundaries. IDs identify top-level steps, not setup or parallel children.
public struct PlaybackRequest: Codable, Sendable {
    public var script: FilmScript
    public var from: JSONValue?
    public var to: JSONValue?
    public var output: String?
    public var screenshot: String?

    public init(script: FilmScript) { self.script = script }

    public func selectedRange() throws -> Range<Int> {
        func index(_ reference: JSONValue?, fallback: Int) throws -> Int {
            guard let reference else { return fallback }
            if case .number(let number) = reference, number.isFinite, number.rounded() == number,
               number >= 1, number <= Double(script.steps.count) { return Int(number) - 1 }
            if case .string(let id) = reference, let index = script.steps.firstIndex(where: { $0.id == id }) { return index }
            throw ShowtimeError("Step boundaries must be a one-based step number or an existing top-level step ID.")
        }
        guard !script.steps.isEmpty else { throw ShowtimeError("A film needs at least one step.") }
        let lower = try index(from, fallback: 0)
        let upper = try index(to, fallback: script.steps.count - 1)
        guard lower <= upper else { throw ShowtimeError("The starting step must not come after the ending step.") }
        return lower..<(upper + 1)
    }
}

public struct CameraState: Sendable {
    public var scale: Double
    public var focus: CGPoint
    public var offset: CGPoint = .zero
    public var rotation: Double = 0
    public var flipX = false
    public var flipY = false

    public init(scale: Double = 1, focus: CGPoint = CGPoint(x: 928, y: 480)) {
        self.scale = scale; self.focus = focus
    }

    public var isIdentity: Bool {
        abs(scale - 1) < 0.0001 && offset == .zero && rotation == 0 && !flipX && !flipY
    }

    /// Shared by native preview, exported pixels, pointer drawing, and inverse input mapping.
    public var transform: CGAffineTransform {
        CGAffineTransform(translationX: focus.x + offset.x, y: focus.y + offset.y)
            .rotated(by: rotation * .pi / 180)
            .scaledBy(x: scale * (flipX ? -1 : 1), y: scale * (flipY ? -1 : 1))
            .translatedBy(x: -focus.x, y: -focus.y)
    }
}
