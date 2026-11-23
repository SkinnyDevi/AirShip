// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "AirShipKit",
	platforms: [
		.iOS(.v26),
		.macOS(.v26),
	],
	products: [
		.library(
			name: "AirShipKit",
			targets: ["AirShipKit"]
		)
	],
	targets: [
		.target(
			name: "AirShipKit",
			path: ".",
			exclude: ["Tests", "Info.plist", "README.md", "AirShipApp.swift", "AirShip.xcodeproj"],
			sources: [
				"CoreBridge",
				"Components",
				"Features",
			],
			resources: [
				.process("Resources"),
			]
		),
		.testTarget(
			name: "AirShipKitTests",
			dependencies: ["AirShipKit"],
			path: "Tests"
		),
	]
)
