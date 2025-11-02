// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftSGP4",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "SwiftSGP4",
      targets: ["SwiftSGP4"])
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // No external dependencies - pure Swift implementation
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "SwiftSGP4",
      path: "SwiftSGP4"),
    .testTarget(
      name: "SwiftSGP4Tests",
      dependencies: ["SwiftSGP4"],
      path: "SwiftSGP4Tests",
      resources: [.process("Resources")]),
  ]
)
