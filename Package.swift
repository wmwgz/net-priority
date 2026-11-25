// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetPriority",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NetPriorityCore", targets: ["NetPriorityCore"]),
        .executable(name: "NetPriority", targets: ["NetPriorityApp"])
    ],
    targets: [
        .target(
            name: "NetPriorityCore",
            linkerSettings: [
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .executableTarget(
            name: "NetPriorityApp",
            dependencies: ["NetPriorityCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .executableTarget(
            name: "NetPrioritySelfTest",
            dependencies: ["NetPriorityCore"],
            path: "Tests/NetPriorityCoreTests"
        )
    ]
)
