import Foundation
import CoreGraphics
import ShowtimeCore

final class ScriptTests {
    private func script(_ json: String) throws -> FilmScript {
        try JSONDecoder().decode(FilmScript.self, from: Data(json.utf8))
    }

    func testMinimalScriptUsesDefaults() throws {
        let film = try script(#"{"steps":[{"action":"wait","duration":0.2}]}"#)
        try film.validate()
        XCTAssertEqual(film.version, 1)
        XCTAssertEqual(film.name, "Untitled film")
        XCTAssertNil(film.recording)
    }

    func testUnknownActionIsRejectedBeforeExecution() {
        XCTAssertThrowsError(try script(#"{"steps":[{"action":"clik"}]}"#))
    }

    func testInvalidLaterCuePreventsWholeFilm() throws {
        let film = try script(##"{"steps":[{"action":"click","selector":"#save"},{"action":"zoom","scale":10}]}"##)
        XCTAssertThrowsError(try film.validate()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Step 2"))
        }
    }

    func testTargetNeedsBothCoordinates() throws {
        let film = try script(#"{"steps":[{"action":"click","x":40}]}"#)
        XCTAssertThrowsError(try film.validate())
    }

    func testRecordAspectRatioIsPreserved() throws {
        let film = try script(#"{"canvas":{"width":1440,"height":900},"recording":{"width":1920,"height":1080},"steps":[{"action":"wait"}]}"#)
        XCTAssertThrowsError(try film.validate()) { error in XCTAssertTrue(error.localizedDescription.contains("aspect ratios")) }
    }

    func testOddH264DimensionsAreRejected() throws {
        let film = try script(#"{"recording":{"width":1919,"height":1080},"steps":[{"action":"wait"}]}"#)
        XCTAssertThrowsError(try film.validate())
    }

    func testVideoFollowsLandscapeAndPortraitCanvas() throws {
        var canvas = CanvasSpec(), video = RecordingSpec()
        video.fps = 60; video.output = "/tmp/product-film.mp4"
        let wide = try video.fitted(to: canvas, longEdge: 3840)
        XCTAssertEqual(wide.width, 3840); XCTAssertEqual(wide.height, 2160)
        canvas.width = 900; canvas.height = 1600
        let portrait = try video.fitted(to: canvas)
        XCTAssertEqual(portrait.width, 1080); XCTAssertEqual(portrait.height, 1920)
        XCTAssertEqual(portrait.fps, 60); XCTAssertEqual(portrait.output, video.output)
        let bounded = try video.fitted(to: canvas, longEdge: 3840)
        try bounded.validate(canvas: canvas)
        XCTAssertLessThanOrEqual(bounded.height, 2160)
        canvas.width = 1440; canvas.height = 900
        let desktop = try video.fitted(to: canvas)
        XCTAssertEqual(desktop.width, 1920); XCTAssertEqual(desktop.height, 1200)
    }

    func testCustomCanvasAlwaysProducesCompatibleVideo() throws {
        for width in [800, 801, 1333, 2560, 3840] {
            for height in [500, 501, 811, 1600, 2160] {
                var canvas = CanvasSpec(); canvas.width = width; canvas.height = height
                for edge in [1280, 1920, 3840] {
                    let video = try RecordingSpec().fitted(to: canvas, longEdge: edge)
                    try video.validate(canvas: canvas)
                }
            }
        }
    }

    func testVideoFittingDoesNotHideInvalidSettings() throws {
        var canvas = CanvasSpec(), video = RecordingSpec()
        video.fps = 25
        XCTAssertThrowsError(try video.fitted(to: canvas))
        video.fps = 24; canvas.width = 400
        XCTAssertThrowsError(try video.fitted(to: canvas))
    }

    func testCustomVideoSurvivesAppearanceAndFrameRateEdits() throws {
        var canvas = CanvasSpec(), video = RecordingSpec()
        video.width = 1920; video.height = 1082; video.fps = 60
        canvas.browserTheme = "dark"
        XCTAssertEqual(try video.fitted(to: canvas), video)
    }

    func testDeviceFramesScaleContentWithCanvas() throws {
        let oldCanvas = try JSONDecoder().decode(CanvasSpec.self, from: Data(#"{"width":1920,"height":1080}"#.utf8))
        XCTAssertEqual(oldCanvas.frame, .none)
        XCTAssertEqual(oldCanvas.layout.page, CGRect(x: 0, y: 56, width: 1856, height: 960))
        XCTAssertEqual(oldCanvas.layout.origin, CGPoint(x: 32, y: 32))
        XCTAssertEqual(oldCanvas.layout.scale, 1)
        var canvas = oldCanvas
        canvas.frame = .iphone16Pro
        XCTAssertEqual(canvas.layout.page.width, 402); XCTAssertEqual(canvas.layout.page.height, 790)
        XCTAssertEqual(DeviceFrame.allCases.map(\.rawValue),
                       ["none", "iphone-16-pro", "iphone-16-pro-max", "ipad-pro-11", "ipad-pro-13", "macbook-neo", "macbook-pro"])
        for (legacy, replacement) in [("iphone-se", DeviceFrame.iphone16Pro), ("ipad-mini", .ipadPro11), ("macbook", .macbookNeo)] {
            let saved = try JSONDecoder().decode(CanvasSpec.self, from: Data("""
                {"width":900,"height":1600,"inset":40,"backdrop":"pearl","browserTheme":"dark","frame":"\(legacy)"}
                """.utf8))
            XCTAssertEqual(saved.frame, replacement)
            XCTAssertEqual(saved.width, 900); XCTAssertEqual(saved.height, 1600); XCTAssertEqual(saved.inset, 40)
            XCTAssertEqual(saved.backdrop, "pearl"); XCTAssertEqual(saved.browserTheme, "dark")
            let encoded = try JSONEncoder().encode(saved)
            let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            XCTAssertEqual(object["frame"] as? String, replacement.rawValue)
        }
        for device in DeviceFrame.allCases {
            canvas.frame = device
            try canvas.validate()
            XCTAssertEqual(try RecordingSpec().fitted(to: canvas), RecordingSpec())
            let encoded = try JSONEncoder().encode(canvas)
            XCTAssertEqual(try JSONDecoder().decode(CanvasSpec.self, from: encoded), canvas)
            for (width, height) in [(800, 500), (1920, 1080), (900, 1600), (2560, 1600), (3840, 2160)] {
                canvas.width = width; canvas.height = height
                try canvas.validate()
                let layout = canvas.layout
                let frame = layout.onCanvas(CGRect(origin: .zero, size: layout.size))
                XCTAssertGreaterThanOrEqual(frame.minX, canvas.inset - 0.001)
                XCTAssertGreaterThanOrEqual(frame.minY, canvas.inset - 0.001)
                XCTAssertLessThanOrEqual(frame.maxX, Double(width) - canvas.inset + 0.001)
                XCTAssertLessThanOrEqual(frame.maxY, Double(height) - canvas.inset + 0.001)
                XCTAssertTrue(layout.screen.contains(layout.page))
                if device != .none { XCTAssertEqual(layout.screen.size, device.referenceScreenSize) }
                if device.isMacBook {
                    XCTAssertTrue(CGRect(origin: .zero, size: layout.size).contains(layout.base))
                    let outline = layout.screenPath(in: layout.canvasScreen)
                    XCTAssertTrue(outline.contains(CGPoint(x: layout.canvasScreen.minX + 0.01, y: layout.canvasScreen.maxY - 0.01)))
                    XCTAssertTrue(!outline.contains(CGPoint(x: layout.canvasScreen.minX + 0.01, y: layout.canvasScreen.minY + 0.01)))
                }
            }
            canvas.width = oldCanvas.width; canvas.height = oldCanvas.height
        }
        canvas.frame = .macbookNeo; canvas.width = 3064; canvas.height = 1888
        try canvas.validate()
        XCTAssertEqual(canvas.pageWidth, 2408); XCTAssertEqual(canvas.pageHeight, 1394)
        XCTAssertEqual(canvas.layout.canvasPage, CGRect(x: 328, y: 220, width: 2408, height: 1394))
        canvas.width = 3840; canvas.height = 2160
        XCTAssertGreaterThanOrEqual(canvas.pageHeight, 1600)
        let video = try RecordingSpec().fitted(to: canvas, longEdge: 3840)
        XCTAssertEqual(video.width, 3840); XCTAssertEqual(video.height, 2160)
        canvas.frame = .macbookPro
        XCTAssertEqual(canvas.layout.screen.size, CGSize(width: 1728, height: 1080))
        XCTAssertEqual(canvas.layout.page.width / canvas.layout.page.height, 1.6)
        XCTAssertEqual(canvas.layout.page, canvas.layout.screen)
        XCTAssertGreaterThanOrEqual(canvas.pageHeight, 1600)
        XCTAssertThrowsError(try JSONDecoder().decode(CanvasSpec.self, from: Data(#"{"frame":"unknown-phone"}"#.utf8)))
        canvas.frame = .none; canvas.width = 800; canvas.height = 500; canvas.inset = 160
        XCTAssertThrowsError(try canvas.validate())
    }

    func testFixedContentWidthCentersAndValidatesFrames() throws {
        var canvas = CanvasSpec()
        canvas.width = 3840; canvas.height = 2160; canvas.inset = 160; canvas.contentWidth = 2000
        try canvas.validate()
        let screen = canvas.layout.canvasScreen
        XCTAssertLessThanOrEqual(abs(screen.width - 2000), 0.001)
        XCTAssertLessThanOrEqual(abs(screen.height - 1125), 0.001)
        XCTAssertLessThanOrEqual(abs(screen.minX - 920), 0.001)
        XCTAssertLessThanOrEqual(abs(screen.minY - 517.5), 0.001)
        canvas.frame = .macbookPro
        try canvas.validate()
        XCTAssertLessThanOrEqual(abs(canvas.pageWidth - 2000), 0.001)
        XCTAssertLessThanOrEqual(abs(canvas.pageHeight - 1250), 0.001)
        let video = try RecordingSpec().fitted(to: canvas, longEdge: 3840)
        XCTAssertEqual(video.width, 3840); XCTAssertEqual(video.height, 2160)

        for frame in DeviceFrame.allCases {
            canvas.frame = frame
            let maximum = canvas.maximumContentWidth
            canvas.contentWidth = maximum
            try canvas.validate()
            let layout = canvas.layout
            XCTAssertLessThanOrEqual(abs(layout.canvasPage.width - Double(maximum)), 0.001)
            let bounds = layout.onCanvas(CGRect(origin: .zero, size: layout.size))
            XCTAssertGreaterThanOrEqual(bounds.minX, -0.001); XCTAssertGreaterThanOrEqual(bounds.minY, -0.001)
            XCTAssertLessThanOrEqual(bounds.maxX, 3840.001); XCTAssertLessThanOrEqual(bounds.maxY, 2160.001)
            XCTAssertLessThanOrEqual(abs(bounds.midX - 1920), 0.001)
            XCTAssertLessThanOrEqual(abs(bounds.midY - 1080), 0.001)
            canvas.inset = 0
            XCTAssertEqual(canvas.layout.canvasScreen, layout.canvasScreen)
            canvas.inset = 160
            XCTAssertEqual(try JSONDecoder().decode(CanvasSpec.self, from: JSONEncoder().encode(canvas)), canvas)
            for invalid in [0, -1, maximum + 1] {
                canvas.contentWidth = invalid
                XCTAssertThrowsError(try canvas.validate())
            }
        }
        for json in [#"{}"#, #"{"contentWidth":null}"#] {
            let automatic = try JSONDecoder().decode(CanvasSpec.self, from: Data(json.utf8))
            XCTAssertNil(automatic.contentWidth)
            XCTAssertEqual(automatic.layout.canvasPage, CGRect(x: 32, y: 88, width: 1856, height: 960))
        }
        XCTAssertThrowsError(try JSONDecoder().decode(CanvasSpec.self, from: Data(#"{"contentWidth":1200.5}"#.utf8)))
        let migrated = try JSONDecoder().decode(CanvasSpec.self, from: Data(#"{"width":3840,"height":2160,"frame":"macbook","contentWidth":2000}"#.utf8))
        try migrated.validate()
        XCTAssertEqual(migrated.frame, .macbookNeo); XCTAssertEqual(migrated.contentWidth, 2000)
    }

    func testParallelTracksCannotRaceForTheSameProperty() throws {
        let film = try script(#"{"steps":[{"action":"parallel","steps":[{"action":"zoom","scale":2},{"action":"zoom","scale":3}]}]}"#)
        XCTAssertThrowsError(try film.validate())
    }

    func testNativeSideEffectsCannotRunInParallel() throws {
        let film = try script(##"{"steps":[{"action":"parallel","steps":[{"action":"click","selector":"#save"},{"action":"zoom","scale":2}]}]}"##)
        XCTAssertThrowsError(try film.validate())
    }

    func testIndependentVisualTracksCanRunTogether() throws {
        let film = try script(#"{"steps":[{"action":"parallel","steps":[{"action":"move","x":400,"y":300},{"action":"zoom","scale":2},{"action":"caption","text":"Hello"}]}]}"#)
        try film.validate()
    }

    func testCustomCursorMustHaveAnAsset() throws {
        let film = try script(#"{"steps":[{"action":"cursor","style":"custom"}]}"#)
        XCTAssertThrowsError(try film.validate())
    }

    func testCursorHotspotMustStayInsideImage() throws {
        let valid = try script(#"{"steps":[{"action":"cursor","style":"custom","image":"/tmp/cursor.png","hotspotX":0.5,"hotspotY":0.5}]}"#)
        try valid.validate()
        for value in [-0.01, 1.01] {
            var action = Action(.cursor); action.hotspotX = value
            XCTAssertThrowsError(try action.validate())
        }
    }

    func testCursorStylesRemainExplicit() throws {
        for style in ["arrow", "hand", "ring", "dot", "spotlight"] {
            var action = Action(.cursor); action.style = style
            try action.validate()
        }
        var invalid = Action(.cursor); invalid.style = "unknown"
        XCTAssertThrowsError(try invalid.validate())
    }

    func testUnknownColorAndEasingFailValidation() throws {
        for json in [#"{"steps":[{"action":"cursor","color":"purple"}]}"#, #"{"steps":[{"action":"move","x":1,"y":1,"easing":"fast"}]}"#] {
            XCTAssertThrowsError(try script(json).validate())
        }
    }

    func testAssertionValuesDistinguishBooleansFromNumbers() throws {
        let boolean = try JSONDecoder().decode(JSONValue.self, from: Data("true".utf8))
        let number = try JSONDecoder().decode(JSONValue.self, from: Data("1".utf8))
        XCTAssertNotEqual(boolean, number)
    }

    func testBundledFilmIsValid() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Sources/Showtime/Resources/Scripts/orbit-launch.json"))
        let film = try JSONDecoder().decode(FilmScript.self, from: data)
        try film.validate()
        XCTAssertTrue(film.steps.contains { $0.action == .assert })
        XCTAssertEqual(film.steps.filter { $0.action == .marker }.count, 5)
    }

    func testCameraKeepsItsFocusStationary() {
        let (x,y) = Motion.cameraPoint(x: 620,y: 350,focusX: 620,focusY: 350,scale: 2.6)
        XCTAssertEqual(x,620);XCTAssertEqual(y,350)
        let (identityX,identityY) = Motion.cameraPoint(x: 100,y: 200,focusX: 620,focusY: 350,scale: 1)
        XCTAssertEqual(identityX,100);XCTAssertEqual(identityY,200)
    }

    func testCinematicEasingIsMonotonicAndHasExactEndpoints() {
        for curve in ["linear","smooth","cinematic"] {
            XCTAssertEqual(Motion.ease(0,curve:curve),0)
            XCTAssertEqual(Motion.ease(1,curve:curve),1)
            var previous=0.0
            for i in 0...100 {
                let value=Motion.ease(Double(i)/100,curve:curve)
                XCTAssertGreaterThanOrEqual(value,previous)
                XCTAssertLessThanOrEqual(value,1)
                previous=value
            }
        }
    }
}
