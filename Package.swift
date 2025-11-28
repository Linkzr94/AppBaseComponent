// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EGBaseSwift",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "EGBaseSwift", targets: ["EGBaseSwift"])
    ],
    dependencies: [
        // eg frameworks
        .package(url: "git@github.com:Linkzr94/SourceryTemplateTest.git", branch: "main"),
        
        // vendors
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.10.0")),
    ],
    targets: [
        .target(
            name: "EGBaseSwift",
            dependencies: [
                "Core", "HTTPClient", "Logger"
            ],
            path: "Sources/EGBaseSwift"
        ),
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .target(
            name: "Logger",
            dependencies: [
                "Core"
            ],
            path: "Sources/Logger"
        ),
        .target(
            name: "HTTPClient",
            dependencies: [
                "Core", "Logger",
                .product(name: "Alamofire", package: "Alamofire"),
            ],
            path: "Sources/HTTPClient"
        ),
    ]
)
