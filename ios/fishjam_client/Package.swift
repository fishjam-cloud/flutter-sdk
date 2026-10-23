// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "fishjam_client",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "fishjam-client", targets: ["fishjam_client"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // The Flutter tool resolves this path to the flutter_webrtc plugin package.
        // WebRTC below is that package's own binary (150.7871.01 in flutter_webrtc 1.6.2).
        .package(name: "flutter_webrtc", path: "../flutter_webrtc")
    ],
    targets: [
        .target(
            name: "fishjam_client",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "flutter-webrtc", package: "flutter_webrtc"),
                .product(name: "WebRTC", package: "flutter_webrtc")
            ]
        )
    ]
)
