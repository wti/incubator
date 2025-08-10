// swift-tools-version: 6.1

import PackageDescription

let tags = "tags"
let tagDemo = "tagDemo"
let main = "\(tagDemo)Main"
let benchPack = "package-benchmark"

let package = Package(
  name: tags,
  platforms: [.macOS(.v15)],
  products: [
    .library(name: tags, targets: ["tags"]),
    .library(name: tagDemo, targets: ["tagDemo"]),
    .executable(name: main, targets: ["tagDemoMain"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/ordo-one/\(benchPack)",
      .upToNextMajor(from: "1.29.3")
    )
  ],
  targets: [  // RUN: tagDemo
    .target(name: tags),
    .target(name: tagDemo, dependencies: ["tags"]),
    .executableTarget(name: main, dependencies: ["tagDemo"]),
    .testTarget(
      name: "\(tags)Tests",
      dependencies: [
        .target(name: tags),
        .target(name: tagDemo),
      ]
    ),
    // TagSpeed Benchmark
    // run with `swift package benchmark --target TagSpeed --format markdown`
    .executableTarget(
      name: "TagSpeed",
      dependencies: [
        .product(name: "Benchmark", package: benchPack),
        .target(name: tags),
        .target(name: tagDemo),
      ],
      path: "Benchmarks/TagSpeed",
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: benchPack)
      ]
    ),
  ]
)
