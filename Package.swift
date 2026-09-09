// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Showtime",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Showtime", targets: ["Showtime"]),
        .library(name: "ShowtimeCore", targets: ["ShowtimeCore"]),
        .executable(name: "ShowtimeChecks", targets: ["ShowtimeChecks"]),
    ],
    targets: [
        .target(name: "ShowtimeCore"),
        .executableTarget(
            name: "Showtime",
            dependencies: ["ShowtimeCore"],
            resources: [.copy("Resources/Demo"), .copy("Resources/Scripts")],
            linkerSettings: [
                .linkedFramework("SwiftUI"), .linkedFramework("WebKit"),
                .linkedFramework("AVFoundation"), .linkedFramework("Network"),
            ]
        ),
        // The standalone check runner also works with Command Line Tools, which ship no XCTest SDK.
        .executableTarget(name: "ShowtimeChecks", dependencies: ["ShowtimeCore"], path: "Tests/ShowtimeCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
