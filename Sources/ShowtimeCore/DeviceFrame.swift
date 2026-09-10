import Foundation
import CoreGraphics

public enum DeviceFrame: String, Codable, CaseIterable, Sendable {
    case none
    case iphoneSE = "iphone-se"
    case iphone16Pro = "iphone-16-pro"
    case iphone16ProMax = "iphone-16-pro-max"
    case ipadMini = "ipad-mini"
    case ipadPro11 = "ipad-pro-11"
    case ipadPro13 = "ipad-pro-13"
    case macbook

    public var title: String {
        switch self {
        case .none: return "None"
        case .iphoneSE: return "iPhone SE"
        case .iphone16Pro: return "iPhone 16 Pro"
        case .iphone16ProMax: return "iPhone 16 Pro Max"
        case .ipadMini: return "iPad mini"
        case .ipadPro11: return "iPad Pro 11″"
        case .ipadPro13: return "iPad Pro 13″"
        case .macbook: return "MacBook 13″"
        }
    }

    /// Logical display sizes; the webpage uses the space below device status UI.
    public var displaySize: CGSize {
        switch self {
        case .none: return .zero
        case .iphoneSE: return CGSize(width: 375, height: 667)
        case .iphone16Pro: return CGSize(width: 402, height: 874)
        case .iphone16ProMax: return CGSize(width: 440, height: 956)
        case .ipadMini: return CGSize(width: 744, height: 1133)
        case .ipadPro11: return CGSize(width: 834, height: 1194)
        case .ipadPro13: return CGSize(width: 1032, height: 1376)
        case .macbook: return CGSize(width: 1440, height: 900)
        }
    }

    public var isPhone: Bool { self == .iphoneSE || self == .iphone16Pro || self == .iphone16ProMax }
    public var isTablet: Bool { self == .ipadMini || self == .ipadPro11 || self == .ipadPro13 }
    public var showsBrowserChrome: Bool { self == .none || self == .macbook }
    public var symbol: String {
        if isPhone { return self == .iphoneSE ? "iphone.gen1" : "iphone.gen3" }
        if isTablet { return "ipad" }
        return self == .macbook ? "laptopcomputer" : "rectangle.dashed"
    }
}

/// One coordinate system for the live WebKit view, hardware, exported frames,
/// and pointer effects. Device fitting never changes its CSS viewport.
public struct FrameLayout: Sendable {
    public let size: CGSize
    public let body: CGRect
    public let screen: CGRect
    public let page: CGRect
    public let bodyRadius: Double
    public let screenRadius: Double
    public let scale: Double
    public let origin: CGPoint

    public init(canvas: CanvasSpec) {
        let frame = canvas.frame, display = frame.displaySize
        let top: Double, bottom: Double
        switch frame {
        case .none:
            size = CGSize(width: Double(canvas.width) - canvas.inset * 2, height: Double(canvas.height) - canvas.inset * 2)
            body = CGRect(origin: .zero, size: size)
            screen = body
            bodyRadius = 13; screenRadius = 13
            top = CanvasSpec.chromeHeight; bottom = 0
        case .iphoneSE:
            size = CGSize(width: display.width + 64, height: display.height + 222)
            body = CGRect(x: 3, y: 0, width: size.width - 6, height: size.height)
            screen = CGRect(x: 32, y: 111, width: display.width, height: display.height)
            bodyRadius = 62; screenRadius = 2
            top = 20; bottom = 0
        case .iphone16Pro, .iphone16ProMax:
            size = CGSize(width: display.width + 30, height: display.height + 24)
            body = CGRect(x: 3, y: 0, width: size.width - 6, height: size.height)
            screen = CGRect(x: 15, y: 12, width: display.width, height: display.height)
            bodyRadius = 62; screenRadius = 50
            top = 56; bottom = 28
        case .ipadMini, .ipadPro11, .ipadPro13:
            let bezel: Double = frame == .ipadMini ? 60 : 22
            size = CGSize(width: display.width + bezel * 2 + 6, height: display.height + bezel * 2)
            body = CGRect(x: 3, y: 0, width: size.width - 6, height: size.height)
            screen = CGRect(x: bezel + 3, y: bezel, width: display.width, height: display.height)
            bodyRadius = frame == .ipadMini ? 50 : 38; screenRadius = 18
            top = 24; bottom = 22
        case .macbook:
            size = CGSize(width: display.width + 172, height: display.height + 90)
            body = CGRect(x: 70, y: 0, width: display.width + 32, height: display.height + 56)
            screen = CGRect(x: 86, y: 16, width: display.width, height: display.height)
            bodyRadius = 24; screenRadius = 9
            top = CanvasSpec.chromeHeight; bottom = 0
        }
        page = CGRect(x: screen.minX, y: screen.minY + top, width: screen.width, height: screen.height - top - bottom)
        scale = min((Double(canvas.width) - canvas.inset * 2) / size.width,
                    (Double(canvas.height) - canvas.inset * 2) / size.height)
        origin = CGPoint(x: (Double(canvas.width) - size.width * scale) / 2,
                         y: (Double(canvas.height) - size.height * scale) / 2)
    }

    public func onCanvas(_ rect: CGRect) -> CGRect {
        CGRect(x: origin.x + rect.minX * scale, y: origin.y + rect.minY * scale,
               width: rect.width * scale, height: rect.height * scale)
    }
}
