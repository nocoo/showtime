import AppKit
import ImageIO

/// Fetch only page-declared icons (then the conventional origin favicon).
/// This never receives the local automation server's credentials.
@MainActor
enum SiteFavicon {
    private static let byteLimit = 2 * 1024 * 1024

    static func load(links: [String], pageURL: URL) async -> NSImage? {
        var candidates = links.compactMap { URL(string: $0, relativeTo: pageURL)?.absoluteURL }
        if ["http", "https"].contains(pageURL.scheme?.lowercased() ?? ""),
           let fallback = URL(string: "/favicon.ico", relativeTo: pageURL)?.absoluteURL,
           !candidates.contains(fallback) { candidates.append(fallback) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 6
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        for url in candidates {
            guard !Task.isCancelled else { return nil }
            guard let data = try? await data(at: url, pageURL: pageURL, session: session),
                  !data.isEmpty, data.count <= byteLimit else { continue }
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceCreateThumbnailWithTransform: true,
               ] as CFDictionary) {
                return NSImage(cgImage: cgImage, size: NSSize(width: 16, height: 16))
            }
            // NSImage also understands SVG, a common modern favicon format.
            if let image = NSImage(data: data), image.isValid { return image }
        }
        return nil
    }

    private static func data(at url: URL, pageURL: URL, session: URLSession) async throws -> Data? {
        switch url.scheme?.lowercased() {
        case "http", "https":
            let (bytes, response) = try await session.bytes(for: URLRequest(url: url))
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
                  response.expectedContentLength <= byteLimit else { return nil }
            var result = Data()
            for try await byte in bytes {
                guard result.count < byteLimit else { return nil }
                result.append(byte)
            }
            return result
        case "data":
            let parts = url.absoluteString.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].lowercased().hasPrefix("data:image/"), parts[1].utf8.count <= byteLimit * 3 else { return nil }
            if parts[0].lowercased().hasSuffix(";base64") { return Data(base64Encoded: String(parts[1])) }
            return String(parts[1]).removingPercentEncoding?.data(using: .utf8)
        case "file":
            // A local page may use icons from its own read-access directory.
            // Remote HTML must never trigger reads from the local filesystem.
            guard pageURL.isFileURL else { return nil }
            let directory = pageURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path + "/"
            let file = url.resolvingSymlinksInPath().standardizedFileURL
            guard file.path.hasPrefix(directory),
                  let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= byteLimit else { return nil }
            return try Data(contentsOf: file)
        default: return nil
        }
    }
}
