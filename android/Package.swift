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
        // Upper bounds: skip-fuse-ui 1.19 / skip 1.9.13 moved to github.com URLs, which
        // conflicts with skip-web 0.11.3 (source.skip.tools) — and skip-web 0.12.0 crashes
        // (NPE below). Lift all four together once skip-web ships a fix.
        .package(url: "https://source.skip.tools/skip.git", "1.9.4"..<"1.9.9"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", "1.0.0"..<"1.19.0"),
        .package(url: "https://source.skip.tools/skip-keychain.git", "0.3.2"..<"0.3.4"),
        // Transitive pins for the same reason: swift-android-native 1.5.2+ pulls swift-jni
        // from github.com and its newer API breaks skip-android-bridge 0.6.x (BundleAccess).
        .package(url: "https://source.skip.tools/swift-android-native.git", exact: "1.5.1"),
        .package(url: "https://source.skip.tools/skip-android-bridge.git", exact: "0.6.3"),
        .package(url: "https://source.skip.tools/swift-jni.git", exact: "0.5.0"),
        .package(url: "https://source.skip.tools/skip-web.git", exact: "0.11.3")  // 0.12.0 crashes: NPE in androidRequestHeaders during shouldOverrideUrlLoading
    ],
    targets: [
        .target(name: "Riftcount", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "SkipKeychain", package: "skip-keychain"),
            .product(name: "SkipWeb", package: "skip-web")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
