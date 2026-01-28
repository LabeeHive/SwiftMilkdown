// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ExampleApp",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
  ],
  dependencies: [
    .package(path: "..")
  ],
  targets: [
    .executableTarget(
      name: "ExampleApp",
      dependencies: [
        .product(name: "SwiftMilkdown", package: "SwiftMilkdown")
      ]
    )
  ]
)
