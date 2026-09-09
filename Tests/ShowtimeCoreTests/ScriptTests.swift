import Foundation
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
