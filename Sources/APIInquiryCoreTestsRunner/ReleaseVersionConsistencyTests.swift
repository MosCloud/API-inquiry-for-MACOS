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
            appVersionSource.contains("static let displayVersion = \"v0.3.10\""),
            "settings app version is v0.3.10"
        )
        harness.expectTrue(
            versionEnv.contains("APP_VERSION=\"0.3.10\""),
            "packaging app version is 0.3.10"
        )
        harness.expectTrue(
            versionEnv.contains("DMG_BASENAME=\"API-Inquiry-v0.3.10\""),
            "dmg basename is v0.3.10"
        )
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
