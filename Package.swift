// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "SwiftMilkdown",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "SwiftMilkdown",
      targets: ["SwiftMilkdown"]
    )
  ],
  targets: [
    .target(
      name: "SwiftMilkdown",
      resources: [
        .copy("Resources/Editor")
      ]
    ),
    .testTarget(
      name: "SwiftMilkdownTests",
      dependencies: ["SwiftMilkdown"]
    ),
  ]
)
