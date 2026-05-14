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
        ),
        .executable(
            name: "APIInquiryCoreTestsRunner",
            targets: ["APIInquiryCoreTestsRunner"]
        ),
        .executable(
            name: "APIInquiryApp",
            targets: ["APIInquiryApp"]
        )
    ],
    targets: [
        .target(
            name: "APIInquiryCore"
        ),
        .executableTarget(
            name: "APIInquiryCoreTestsRunner",
            dependencies: ["APIInquiryCore"]
        ),
        .executableTarget(
            name: "APIInquiryApp",
            dependencies: ["APIInquiryCore"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
