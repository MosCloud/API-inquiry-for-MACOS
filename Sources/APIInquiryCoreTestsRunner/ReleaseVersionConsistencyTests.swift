import Foundation

enum ReleaseVersionConsistencyTests {
    static func run(using harness: TestHarness) {
        let root = repositoryRoot()
        let versionEnvPath = root.appendingPathComponent("Scripts").appendingPathComponent("version.env")
        let localBuildPath = root.appendingPathComponent("Scripts").appendingPathComponent("build-local-app.sh")
        let packagePath = root.appendingPathComponent("Scripts").appendingPathComponent("package-mac-app.sh")

        let versionEnv = (try? String(contentsOf: versionEnvPath, encoding: .utf8)) ?? ""
        let localBuild = (try? String(contentsOf: localBuildPath, encoding: .utf8)) ?? ""
        let package = (try? String(contentsOf: packagePath, encoding: .utf8)) ?? ""

        harness.expectTrue(versionEnv.contains("APP_VERSION=\"0.3.16\""), "packaging app version is 0.3.16")
        harness.expectTrue(versionEnv.contains("RELEASE_TAG=\"release/v0.3.16\""), "release tag is v0.3.16")
        harness.expectTrue(versionEnv.contains("RELEASE_VERSION=\"0.3.16\""), "release version is 0.3.16")
        harness.expectTrue(versionEnv.contains("DMG_BASENAME=\"API-Inquiry-v0.3.16\""), "dmg basename is v0.3.16")
        harness.expectTrue(versionEnv.contains("VOLUME_NAME=\"API Inquiry v0.3.16\""), "volume name is v0.3.16")
        harness.expectTrue(versionEnv.contains("BUILD_NUMBER=\"21\""), "build number is 21")

        // Development builds must not advertise the release version, and must record
        // the commit that produced them.
        harness.expectTrue(
            localBuild.contains("<string>0.0.0-dev</string>"),
            "local builds mark themselves as development"
        )
        harness.expectTrue(
            localBuild.contains("APIInquiryGitCommit"),
            "local builds record the git commit"
        )

        // Release packaging is the only place a real version number is written, and it
        // refuses to ship a development build.
        harness.expectTrue(
            package.contains("<string>$APP_VERSION</string>"),
            "release packaging writes the version from version.env"
        )
        harness.expectTrue(
            package.contains("Delete :APIInquiryGitCommit"),
            "release packaging strips the development marker"
        )
        harness.expectTrue(
            package.contains("refusing to package a development build as a release"),
            "release packaging refuses development builds"
        )
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
