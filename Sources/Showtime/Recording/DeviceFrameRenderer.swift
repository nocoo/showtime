import AppKit
import ShowtimeCore

/// Vector hardware stays sharp at every export resolution. The live preview
/// calls this same renderer, including the safe areas around the webpage.
@MainActor
enum DeviceFrameRenderer {
    static func draw(canvas: CanvasSpec, context ctx: CGContext) {
        let layout = canvas.layout, frame = canvas.frame
        let dark = canvas.browserTheme == "dark"
        let indigo = dark && frame == .macbookNeo
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.translateBy(x: layout.origin.x, y: layout.origin.y)
        ctx.scaleBy(x: layout.scale, y: layout.scale)
        let body = layout.body, screen = layout.screen
        let outline = rounded(body, layout.bodyRadius)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: frame == .none ? 9 : 14), blur: frame == .none ? 25 : 28,
                      color: NSColor.black.withAlphaComponent(frame == .none ? 0.19 : 0.22).cgColor)
        fill(outline, frame == .none ? "#FFFFFF" : (dark ? "#222426" : "#B6B9BB"), ctx)
        ctx.restoreGState()
        if frame == .none { return }

        // A narrow machined rim, a reflected edge, then dark cover glass.
        gradient(outline, rect: body, colors: indigo
                 ? ["#8995AB", "#44516A", "#79879F", "#354159"] : dark
                 ? ["#55585B", "#25272A", "#44474A", "#16181A"]
                 : ["#D6D8DA", "#929699", "#E1E3E4", "#8C9094"], context: ctx)
        stroke(rounded(body.insetBy(dx: 1, dy: 1), layout.bodyRadius - 1), indigo ? "#A0ACC0" : dark ? "#686B6E" : "#F5F6F6", width: 0.9, alpha: 0.7, ctx)
        fill(rounded(body.insetBy(dx: 3.2, dy: 3.2), layout.bodyRadius - 3.2), "#111315", ctx)
        stroke(rounded(body.insetBy(dx: 5, dy: 5), layout.bodyRadius - 5), dark ? "#292B2E" : "#434648", width: 0.7, ctx)

        if frame.isPhone || frame.isTablet {
            let buttonY = frame.isTablet ? body.height * 0.12 : 126.0
            let buttonColor = dark ? "#373A3D" : "#AEB1B4"
            fill(rounded(CGRect(x: body.minX - 2.5, y: buttonY, width: 3, height: 25), 1.4), buttonColor, ctx)
            for y in [buttonY + 43, buttonY + 100] where frame.isPhone {
                fill(rounded(CGRect(x: body.minX - 2.5, y: y, width: 3, height: 43), 1.4), buttonColor, ctx)
            }
            fill(rounded(CGRect(x: body.maxX - 0.5, y: buttonY + 61, width: 3, height: frame.isPhone ? 68 : 38), 1.4), buttonColor, ctx)
        }

        let surface = frame.isMacBook ? (dark ? "#25272B" : "#E8EAED") : (dark ? "#242B28" : "#FCFDFB")
        fill(layout.screenPath(in: screen), surface, ctx)
        stroke(layout.screenPath(in: screen), "#000000", width: 1.2, ctx)

        if frame.isPhone || frame.isTablet {
            statusBar(frame: frame, screen: screen, dark: dark, context: ctx)
            if frame.isPhone {
                let island = CGRect(x: screen.midX - 57, y: screen.minY + 10, width: 114, height: 32)
                fill(rounded(island, 16), "#08090B", ctx)
                lens(at: CGPoint(x: island.maxX - 16, y: island.midY), radius: 4.2, context: ctx)
            } else {
                lens(at: CGPoint(x: body.midX, y: screen.minY / 2), radius: 3.8, context: ctx)
            }
            let homeWidth: Double = frame.isPhone ? 120 : 160
            fill(rounded(CGRect(x: screen.midX - homeWidth / 2, y: screen.maxY - 12,
                                width: homeWidth, height: frame.isPhone ? 5 : 4), 2.5), dark ? "#DFE5E0" : "#202522", ctx)
        } else if frame.isMacBook {
            lens(at: CGPoint(x: body.midX, y: screen.minY / 2), radius: 3.2, context: ctx)
            // Current models have plain glass below the display, with a recessed hinge.
            let hinge = CGRect(x: body.minX + 24, y: layout.base.minY - 14, width: body.width - 48, height: 14)
            gradient(rounded(hinge, 7), rect: hinge, colors: ["#1D1E20", "#070809"], vertical: true, context: ctx)
            macbookBase(rect: layout.base, neo: frame == .macbookNeo, dark: dark, context: ctx)
        }
    }

    private static func statusBar(frame: DeviceFrame, screen: CGRect, dark: Bool, context ctx: CGContext) {
        let ink = dark ? "#E7EDE8" : "#222724"
        let compact = frame.isTablet
        let y = screen.minY + (compact ? 4 : 19)
        let margin: Double = frame.isPhone && !compact ? 27 : 16
        label("9:41", rect: CGRect(x: screen.minX + margin, y: y - 1, width: 50, height: 20),
              size: compact ? 11 : 14, color: ink)
        let right = screen.maxX - margin
        let battery = CGRect(x: right - 26, y: y + 1, width: 24, height: 11)
        stroke(rounded(battery, 3), ink, width: 1, alpha: 0.55, ctx)
        fill(rounded(battery.insetBy(dx: 2, dy: 2), 1), ink, ctx)
        fill(rounded(CGRect(x: right - 0.5, y: y + 4, width: 2, height: 5), 1), ink, ctx)
        // Wi-Fi and cellular glyphs use the same small, optically aligned grid.
        for (index, height) in [4.0, 6, 9, 12].enumerated() {
            fill(rounded(CGRect(x: right - 68 + Double(index) * 4.5, y: y + 12 - height, width: 3, height: height), 0.8), ink, ctx)
        }
        ctx.saveGState()
        ctx.setStrokeColor(SceneCompositor.color(ink).cgColor); ctx.setLineWidth(1.8); ctx.setLineCap(.round)
        for radius in [4.5, 8.0] {
            ctx.addArc(center: CGPoint(x: right - 40, y: y + 10), radius: radius,
                       startAngle: -.pi * 0.77, endAngle: -.pi * 0.23, clockwise: false)
            ctx.strokePath()
        }
        fill(rounded(CGRect(x: right - 41, y: y + 10, width: 2, height: 2), 1), ink, ctx)
        ctx.restoreGState()
    }

    private static func macbookBase(rect base: CGRect, neo: Bool, dark: Bool, context ctx: CGContext) {
        // Front-view proportions follow Apple's 2026 product photography; see docs/studio.md.
        let indigo = neo && dark
        for x in [base.width * 0.044, base.width * 0.901] {
            let foot = CGRect(x: x, y: base.maxY - 4, width: base.width * 0.055, height: 16)
            fill(rounded(foot, 8), indigo ? "#3C485F" : dark ? "#1B1D1F" : "#A7A9AB", ctx)
        }
        let path = roundedBottom(base.insetBy(dx: 1, dy: 0), neo ? 14 : 24)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 12, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        fill(path, indigo ? "#44516A" : dark ? "#2D2F32" : "#B8BBBD", ctx)
        ctx.restoreGState()
        gradient(path, rect: base, colors: indigo
                 ? ["#8794AA", "#64738D", "#52617B", "#3D4B63", "#64728B"] : dark
                 ? ["#777A7E", "#53565A", "#43464A", "#2A2D31", "#494C50"]
                 : ["#F0F1F3", "#D7D9DD", "#C6C9CE", "#A7ABB1", "#D3D5D9"], vertical: true, context: ctx)
        stroke(path, indigo ? "#344159" : dark ? "#202226" : "#989CA2", width: 0.9, ctx)
        let gripWidth = base.width * (neo ? 0.18 : 0.153)
        let grip = CGRect(x: base.midX - gripWidth / 2, y: base.minY, width: gripWidth, height: neo ? 20 : 24)
        gradient(roundedBottom(grip, neo ? 15 : 18), rect: grip, colors: indigo
                 ? ["#27354D", "#5F6E87", "#8E9AB0"] : dark
                 ? ["#191B1E", "#4D5055", "#75787C"]
                 : ["#777D85", "#C9CDD2", "#EBEDF0"], vertical: true, context: ctx)
    }

    private static func roundedBottom(_ rect: CGRect, _ radius: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private static func lens(at center: CGPoint, radius: Double, context ctx: CGContext) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        fill(rounded(rect, radius), "#050608", ctx)
        fill(rounded(rect.insetBy(dx: radius * 0.32, dy: radius * 0.32), radius), "#182C40", ctx)
        fill(rounded(CGRect(x: center.x - radius * 0.25, y: center.y - radius * 0.4, width: radius * 0.5, height: radius * 0.5), radius), "#37576B", ctx)
    }

    private static func label(_ text: String, rect: CGRect, size: Double, color: String, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: SceneCompositor.color(color), .paragraphStyle: paragraph]).draw(in: rect)
    }

    private static func rounded(_ rect: CGRect, _ radius: Double) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
    private static func fill(_ path: CGPath, _ hex: String, _ ctx: CGContext) {
        ctx.setFillColor(SceneCompositor.color(hex).cgColor); ctx.addPath(path); ctx.fillPath()
    }
    private static func stroke(_ path: CGPath, _ hex: String, width: Double, alpha: Double = 1, _ ctx: CGContext) {
        ctx.setStrokeColor(SceneCompositor.color(hex, alpha: alpha).cgColor); ctx.setLineWidth(width); ctx.addPath(path); ctx.strokePath()
    }
    private static func gradient(_ path: CGPath, rect: CGRect, colors: [String], vertical: Bool = false, context ctx: CGContext) {
        ctx.saveGState(); ctx.addPath(path); ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: colors.map { SceneCompositor.color($0).cgColor } as CFArray, locations: nil)!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: vertical ? rect.minX : rect.maxX, y: rect.maxY), options: [])
        ctx.restoreGState()
    }
}
