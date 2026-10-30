import Foundation

enum ReleaseVersionConsistencyTests {
    static func run(using harness: TestHarness) {
        let root = repositoryRoot()
        let appVersionPath = root
            .appendingPathComponent("Sources")
            .appendingPathComponent("APIInquiryApp")
            .appendingPathComponent("AppVersion.swift")
        let versionEnvPath = root
            .appendingPathComponent("Scripts")
            .appendingPathComponent("version.env")

        let appVersionSource = (try? String(contentsOf: appVersionPath, encoding: .utf8)) ?? ""
        let versionEnv = (try? String(contentsOf: versionEnvPath, encoding: .utf8)) ?? ""

        harness.expectTrue(
            appVersionSource.contains("static let displayVersion = \"v0.3.16\""),
            "settings app version is v0.3.16"
        )
        harness.expectTrue(
            versionEnv.contains("APP_VERSION=\"0.3.16\""),
            "packaging app version is 0.3.16"
        )
        harness.expectTrue(
            versionEnv.contains("RELEASE_TAG=\"release/v0.3.16\""),
            "release tag is v0.3.16"
        )
        harness.expectTrue(
            versionEnv.contains("RELEASE_VERSION=\"0.3.16\""),
            "release version is 0.3.16"
        )
        harness.expectTrue(
            versionEnv.contains("DMG_BASENAME=\"API-Inquiry-v0.3.16\""),
            "dmg basename is v0.3.16"
        )
        harness.expectTrue(
            versionEnv.contains("VOLUME_NAME=\"API Inquiry v0.3.16\""),
            "volume name is v0.3.16"
        )
        harness.expectTrue(
            versionEnv.contains("BUILD_NUMBER=\"21\""),
            "build number is 21"
        )
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
