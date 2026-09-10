import Foundation
import CoreGraphics

public enum DeviceFrame: String, Codable, CaseIterable, Sendable {
    case none
    case iphone16Pro = "iphone-16-pro"
    case iphone16ProMax = "iphone-16-pro-max"
    case ipadPro11 = "ipad-pro-11"
    case ipadPro13 = "ipad-pro-13"
    case macbookNeo = "macbook-neo"
    case macbookPro = "macbook-pro"

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let name = try value.decode(String.self)
        // Preserve saved Canvas/video settings when retiring a device.
        switch name {
        case "iphone-se": self = .iphone16Pro
        case "ipad-mini": self = .ipadPro11
        case "macbook": self = .macbookNeo
        default:
            guard let frame = Self(rawValue: name) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Unknown device frame: \(name)")
            }
            self = frame
        }
    }

    public var title: String {
        switch self {
        case .none: return "None"
        case .iphone16Pro: return "iPhone 16 Pro"
        case .iphone16ProMax: return "iPhone 16 Pro Max"
        case .ipadPro11: return "iPad Pro 11″"
        case .ipadPro13: return "iPad Pro 13″"
        case .macbookNeo: return "MacBook Neo 13″"
        case .macbookPro: return "MacBook Pro 16″"
        }
    }

    /// Drawing units define screen proportions, never webpage or export resolution.
    public var referenceScreenSize: CGSize {
        switch self {
        case .none: return .zero
        case .iphone16Pro: return CGSize(width: 402, height: 874)
        case .iphone16ProMax: return CGSize(width: 440, height: 956)
        case .ipadPro11: return CGSize(width: 834, height: 1194)
        case .ipadPro13: return CGSize(width: 1032, height: 1376)
        // Neo follows its native panel; Pro presents a clean, notch-free 16:10 screen.
        case .macbookNeo: return CGSize(width: 1204, height: 753)
        case .macbookPro: return CGSize(width: 1728, height: 1080)
        }
    }

    public var isPhone: Bool { self == .iphone16Pro || self == .iphone16ProMax }
    public var isTablet: Bool { self == .ipadPro11 || self == .ipadPro13 }
    public var isMacBook: Bool { self == .macbookNeo || self == .macbookPro }
    public var showsBrowserChrome: Bool { self == .none || self == .macbookNeo }
    public var symbol: String {
        if isPhone { return "iphone.gen3" }
        if isTablet { return "ipad" }
        return isMacBook ? "laptopcomputer" : "rectangle.dashed"
    }
}

/// Reference hardware geometry fitted to the Canvas. The webpage and pointer
/// use canvasPage coordinates, independently of the hardware's drawing units.
public struct FrameLayout: Sendable {
    public let size: CGSize
    public let body: CGRect
    public let screen: CGRect
    public let page: CGRect
    public let base: CGRect
    public let bodyRadius: Double
    public let screenRadius: Double
    public let scale: Double
    public let origin: CGPoint
    private let squareScreenBottom: Bool

    public init(canvas: CanvasSpec) {
        let frame = canvas.frame, display = frame.referenceScreenSize
        let top: Double, bottom: Double
        switch frame {
        case .none:
            size = CGSize(width: Double(canvas.width) - canvas.inset * 2, height: Double(canvas.height) - canvas.inset * 2)
            body = CGRect(origin: .zero, size: size)
            screen = body
            bodyRadius = 13; screenRadius = 13
            top = CanvasSpec.chromeHeight; bottom = 0
        case .iphone16Pro, .iphone16ProMax:
            size = CGSize(width: display.width + 30, height: display.height + 24)
            body = CGRect(x: 3, y: 0, width: size.width - 6, height: size.height)
            screen = CGRect(x: 15, y: 12, width: display.width, height: display.height)
            bodyRadius = 62; screenRadius = 50
            top = 56; bottom = 28
        case .ipadPro11, .ipadPro13:
            let bezel: Double = 22
            size = CGSize(width: display.width + bezel * 2 + 6, height: display.height + bezel * 2)
            body = CGRect(x: 3, y: 0, width: size.width - 6, height: size.height)
            screen = CGRect(x: bezel + 3, y: bezel, width: display.width, height: display.height)
            bodyRadius = 38; screenRadius = 18
            top = 24; bottom = 22
        case .macbookNeo:
            size = CGSize(width: 1500, height: 912)
            body = CGRect(x: 110, y: 0, width: 1280, height: 862)
            screen = CGRect(x: 148, y: 38, width: display.width, height: display.height)
            bodyRadius = 58; screenRadius = 16
            top = CanvasSpec.chromeHeight; bottom = 0
        case .macbookPro:
            size = CGSize(width: 2112, height: 1251)
            body = CGRect(x: 164, y: 0, width: 1784, height: 1173)
            screen = CGRect(x: 192, y: 28, width: display.width, height: display.height)
            bodyRadius = 46; screenRadius = 18
            top = 0; bottom = 0
        }
        squareScreenBottom = frame.isMacBook
        base = frame.isMacBook
            ? CGRect(x: 0, y: body.maxY - 6, width: size.width, height: frame == .macbookNeo ? 44 : 72)
            : .zero
        page = CGRect(x: screen.minX, y: screen.minY + top, width: screen.width, height: screen.height - top - bottom)
        scale = min((Double(canvas.width) - canvas.inset * 2) / size.width,
                    (Double(canvas.height) - canvas.inset * 2) / size.height)
        origin = CGPoint(x: (Double(canvas.width) - size.width * scale) / 2,
                         y: (Double(canvas.height) - size.height * scale) / 2)
    }

    public var canvasScreen: CGRect { onCanvas(screen) }
    public var canvasPage: CGRect { onCanvas(page) }

    /// Both current laptops round only the top display corners. Preview and
    /// export use this same outline, including at non-integer Canvas scales.
    public func screenPath(in rect: CGRect) -> CGPath {
        let radius = screenRadius * rect.width / screen.width
        guard squareScreenBottom else {
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY), radius: radius)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius), radius: radius)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    public func onCanvas(_ rect: CGRect) -> CGRect {
        CGRect(x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
               width: rect.width * scale, height: rect.height * scale)
    }
}
