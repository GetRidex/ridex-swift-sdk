// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RidexSwiftSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "RidexSwiftSDK",
            targets: ["RidexSwiftSDK"]
        ),
    ],
    targets: [
        .target(
            name: "RidexSwiftSDK"
        ),
        .testTarget(
            name: "RidexSwiftSDKTests",
            dependencies: ["RidexSwiftSDK"],
            path: "Tests/RidexSwiftSDKTests"
        ),
    ]
)
