// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "riftcount-app",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Riftcount", type: .dynamic, targets: ["Riftcount"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.9.4"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-keychain.git", from: "0.3.2"),
        .package(url: "https://source.skip.tools/skip-web.git", from: "0.11.3")
    ],
    targets: [
        .target(name: "Riftcount", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "SkipKeychain", package: "skip-keychain"),
            .product(name: "SkipWeb", package: "skip-web")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
