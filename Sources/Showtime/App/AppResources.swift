import AppKit

enum AppResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "Showtime_Showtime", withExtension: "bundle"), let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }()

    static let brandMark: NSImage = {
        guard let url = bundle.url(forResource: "ShowtimeMark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            fatalError("The Showtime toolbar mark is missing from the application resources.")
        }
        return image
    }()
}
