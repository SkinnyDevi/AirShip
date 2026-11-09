// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AirShipKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AirShipKit",
            targets: ["AirShipKit"]
        ),
    ],
    targets: [
        .target(
            name: "AirShipKit",
            path: ".",
            exclude: ["Tests", "Info.plist", "README.md"],
            sources: [
                "CoreBridge",
                "DesignSystem",
                "Features",
            ]
        ),
        .testTarget(
            name: "AirShipKitTests",
            dependencies: ["AirShipKit"],
            path: "Tests"
        ),
    ]
)
