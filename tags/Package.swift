// swift-tools-version: 6.1

import PackageDescription

let tags = "tags"
let tagDemo = "tagDemo"

let package = Package(
  name: tags,
  platforms: [.macOS(.v15)],
  products: [
    .library(name: tags, targets: ["tags"]),
    .executable(name: "tagDemo", targets: ["tagDemo"]),
  ],
  targets: [  // RUN: tagDemo
    .target(name: tags),
    .executableTarget(name: tagDemo, dependencies: ["tags"]),
    .testTarget(name: "\(tags)Tests", dependencies: ["tags"]),
  ]
)
