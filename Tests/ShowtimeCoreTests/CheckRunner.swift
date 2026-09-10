import Foundation

// A tiny runner keeps core verification available on Macs with only Command Line Tools.
// Assertion names match familiar XCTest spelling, but every failure is collected and exits nonzero.
private var failures: [String] = []
private var completed = 0

private func failure(_ message: String, file: StaticString, line: UInt) {
    failures.append("\(file):\(line): \(message)")
}

func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do { if try !expression() { failure("Expected true", file: file, line: line) } }
    catch { failure(error.localizedDescription, file: file, line: line) }
}
func XCTAssertNil<T>(_ expression: @autoclosure () throws -> T?, file: StaticString = #filePath, line: UInt = #line) {
    do { if try expression() != nil { failure("Expected nil", file: file, line: line) } }
    catch { failure(error.localizedDescription, file: file, line: line) }
}
func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { if try lhs() != rhs() { failure("Values are not equal", file: file, line: line) } }
    catch { failure(error.localizedDescription, file: file, line: line) }
}
func XCTAssertNotEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    if lhs == rhs { failure("Expected different values", file: file, line: line) }
}
func XCTAssertGreaterThanOrEqual<T: Comparable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    if lhs < rhs { failure("Expected \(lhs) >= \(rhs)", file: file, line: line) }
}
func XCTAssertLessThanOrEqual<T: Comparable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    if lhs > rhs { failure("Expected \(lhs) <= \(rhs)", file: file, line: line) }
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line, _ handler: (Error) -> Void = { _ in }) {
    do { _ = try expression(); failure("Expected an error", file: file, line: line) }
    catch { handler(error) }
}
func XCTUnwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw NSError(domain: "ShowtimeChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected a value"]) }
    return value
}

@main
enum CheckRunner {
    static func main() {
        let script = ScriptTests(), http = HTTPTests()
        let checks: [(String, () throws -> Void)] = [
            ("Minimal script defaults", script.testMinimalScriptUsesDefaults),
            ("Unknown actions", script.testUnknownActionIsRejectedBeforeExecution),
            ("Whole-script preflight", script.testInvalidLaterCuePreventsWholeFilm),
            ("Coordinate pairs", script.testTargetNeedsBothCoordinates),
            ("Recording aspect ratio", script.testRecordAspectRatioIsPreserved),
            ("H.264 dimensions", script.testOddH264DimensionsAreRejected),
            ("Landscape and portrait video sizing", script.testVideoFollowsLandscapeAndPortraitCanvas),
            ("Custom canvas output compatibility", script.testCustomCanvasAlwaysProducesCompatibleVideo),
            ("Capture settings validation", script.testVideoFittingDoesNotHideInvalidSettings),
            ("Custom output survives appearance and frame-rate edits", script.testCustomVideoSurvivesAppearanceAndFrameRateEdits),
            ("Device proportions, Canvas-sized viewports, 4K fitting, and backward compatibility", script.testDeviceFramesScaleContentWithCanvas),
            ("Parallel track conflicts", script.testParallelTracksCannotRaceForTheSameProperty),
            ("Serialized native input", script.testNativeSideEffectsCannotRunInParallel),
            ("Independent visual tracks", script.testIndependentVisualTracksCanRunTogether),
            ("Custom cursor asset", script.testCustomCursorMustHaveAnAsset),
            ("Cursor hotspot bounds", script.testCursorHotspotMustStayInsideImage),
            ("Cursor style validation", script.testCursorStylesRemainExplicit),
            ("Color and easing validation", script.testUnknownColorAndEasingFailValidation),
            ("JSON assertion types", script.testAssertionValuesDistinguishBooleansFromNumbers),
            ("Bundled film validation", script.testBundledFilmIsValid),
            ("Camera focus invariance", script.testCameraKeepsItsFocusStationary),
            ("Monotonic cinematic motion", script.testCinematicEasingIsMonotonicAndHasExactEndpoints),
            ("Partial HTTP headers", http.testIncompleteHeaderWaitsForMoreData),
            ("Unicode HTTP byte lengths", http.testBodyLengthUsesBytesIncludingUnicode),
            ("Duplicate Content-Length rejection", http.testDuplicateLengthIsRejectedToAvoidRequestSmuggling),
            ("Transfer-Encoding rejection", http.testTransferEncodingIsNotAmbiguous),
            ("Body size limit", http.testOversizedBodyRejectedFromHeaderAlone),
            ("Partial header size limit", http.testHeaderLimitCannotBeBypassedWithPartialUpload),
            ("Invalid body lengths", http.testInvalidAndNegativeLengthsRejected),
            ("Authorization header normalization", http.testAuthorizationHeaderIsCaseInsensitiveButValueIsPreserved),
        ]
        for (name, check) in checks {
            let before = failures.count
            do { try check() }
            catch { failures.append("\(name): \(error.localizedDescription)") }
            print("\(before == failures.count ? "PASS" : "FAIL") \(name)")
            completed += 1
        }
        if !failures.isEmpty {
            for failure in failures { FileHandle.standardError.write(Data("\(failure)\n".utf8)) }
            print("\(failures.count) failures in \(completed) checks.")
            exit(1)
        }
        print("\(completed) checks passed.")
    }
}
