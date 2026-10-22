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
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "fishjam_client",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
