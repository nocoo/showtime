import Foundation

public struct HTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data
}

public enum HTTPParser {
    public static let maximumBody = 2 * 1024 * 1024
    public static let maximumHeader = 32 * 1024

    /// Returns nil until one complete request is available. Connections are closed after one response.
    public static func parse(_ data: Data) throws -> HTTPRequest? {
        let boundary = Data([13, 10, 13, 10])
        guard let range = data.range(of: boundary) else {
            if data.count > maximumHeader { throw ShowtimeError("HTTP headers are too large.") }
            return nil
        }
        guard range.lowerBound <= maximumHeader,
              let header = String(data: data[..<range.lowerBound], encoding: .utf8) else {
            throw ShowtimeError("Invalid HTTP header.")
        }
        let lines = header.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ")
        guard first.count == 3, ["HTTP/1.0", "HTTP/1.1"].contains(String(first[2])), first[1].hasPrefix("/"), first[1].count <= 8192 else {
            throw ShowtimeError("Invalid HTTP request line.")
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":"), line.first != " ", line.first != "\t" else {
                throw ShowtimeError("Invalid HTTP header field.")
            }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, headers[key] == nil else { throw ShowtimeError("Duplicate or empty HTTP header.") }
            headers[key] = value
        }
        guard headers["transfer-encoding"] == nil else { throw ShowtimeError("Chunked requests are not supported; send Content-Length.") }
        let lengthText = headers["content-length"] ?? "0"
        guard !lengthText.isEmpty, lengthText.allSatisfy(\.isNumber), let length = Int(lengthText), (0...maximumBody).contains(length) else {
            throw ShowtimeError("Invalid or oversized Content-Length.")
        }
        let bodyStart = range.upperBound
        guard data.count >= bodyStart + length else { return nil }
        return HTTPRequest(method: String(first[0]), path: String(first[1]), headers: headers,
                           body: data.subdata(in: bodyStart..<(bodyStart + length)))
    }
}
