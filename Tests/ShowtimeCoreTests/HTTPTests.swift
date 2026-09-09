import Foundation
import ShowtimeCore

final class HTTPTests {
    func testIncompleteHeaderWaitsForMoreData() throws {
        XCTAssertNil(try HTTPParser.parse(Data("POST /v1/run HTTP/1.1\r\nHost:".utf8)))
    }

    func testBodyLengthUsesBytesIncludingUnicode() throws {
        let body=Data("{\"text\":\"你好，世界\"}".utf8)
        let header=Data("POST /v1/actions HTTP/1.1\r\nHost: localhost:19840\r\nContent-Length: \(body.count)\r\n\r\n".utf8)
        XCTAssertNil(try HTTPParser.parse(header+body.dropLast()))
        let request=try XCTUnwrap(HTTPParser.parse(header+body))
        XCTAssertEqual(request.body,body)
        XCTAssertEqual(request.path,"/v1/actions")
    }

    func testDuplicateLengthIsRejectedToAvoidRequestSmuggling() {
        let raw="POST /v1/run HTTP/1.1\r\nContent-Length: 0\r\ncontent-length: 1\r\n\r\nx"
        XCTAssertThrowsError(try HTTPParser.parse(Data(raw.utf8)))
    }

    func testTransferEncodingIsNotAmbiguous() {
        let raw="POST /v1/run HTTP/1.1\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"
        XCTAssertThrowsError(try HTTPParser.parse(Data(raw.utf8)))
    }

    func testOversizedBodyRejectedFromHeaderAlone() {
        let raw="POST /v1/run HTTP/1.1\r\nContent-Length: 999999999\r\n\r\n"
        XCTAssertThrowsError(try HTTPParser.parse(Data(raw.utf8)))
    }

    func testHeaderLimitCannotBeBypassedWithPartialUpload() {
        XCTAssertThrowsError(try HTTPParser.parse(Data(repeating: 65,count: HTTPParser.maximumHeader+1)))
    }

    func testInvalidAndNegativeLengthsRejected() {
        for length in ["-1","wat","1.5","+1",""] {
            let raw="POST /v1/run HTTP/1.1\r\nContent-Length: \(length)\r\n\r\n"
            XCTAssertThrowsError(try HTTPParser.parse(Data(raw.utf8)))
        }
    }

    func testAuthorizationHeaderIsCaseInsensitiveButValueIsPreserved() throws {
        let raw="GET /v1/status HTTP/1.1\r\nAUTHORIZATION: Bearer AbCdEf\r\n\r\n"
        XCTAssertEqual(try HTTPParser.parse(Data(raw.utf8))?.headers["authorization"],"Bearer AbCdEf")
    }
}
