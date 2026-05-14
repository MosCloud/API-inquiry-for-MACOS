// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "APIInquiry",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "APIInquiryCore",
            targets: ["APIInquiryCore"]
        )
    ],
    targets: [
        .target(
            name: "APIInquiryCore"
        ),
        .testTarget(
            name: "APIInquiryCoreTests",
            dependencies: ["APIInquiryCore"]
        )
    ]
)
