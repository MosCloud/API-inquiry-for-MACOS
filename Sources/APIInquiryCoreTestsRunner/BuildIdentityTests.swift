import APIInquiryCore

enum BuildIdentityTests {
    static func run(using harness: TestHarness) {
        testDevelopmentBuildIdentifiesTheCommit(using: harness)
        testDirtyDevelopmentBuildSaysSo(using: harness)
        testReleaseBuildShowsTheVersion(using: harness)
        testMissingValuesDegradeGracefully(using: harness)
        testDevelopmentBuildNeverReportsAVersion(using: harness)
    }

    private static func testDevelopmentBuildIdentifiesTheCommit(using harness: TestHarness) {
        let identity = BuildIdentity.resolve(
            shortVersion: "0.0.0-dev",
            gitCommit: "9901c65",
            hasUncommittedChanges: false
        )
        harness.expectEqual(
            identity.source,
            .development(commit: "9901c65", hasUncommittedChanges: false),
            "commit marks the build as development"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .en)),
            "Development version at commit 9901c65",
            "english development text names the commit"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .zh)),
            "开发版本 · 提交 9901c65",
            "chinese development text names the commit"
        )
    }

    private static func testDirtyDevelopmentBuildSaysSo(using harness: TestHarness) {
        let identity = BuildIdentity.resolve(
            shortVersion: "0.0.0-dev",
            gitCommit: "9901c65",
            hasUncommittedChanges: true
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .en)),
            "Development version at commit 9901c65 + dirty",
            "english dirty suffix"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .zh)),
            "开发版本 · 提交 9901c65 + 改动",
            "chinese dirty suffix"
        )
    }

    private static func testReleaseBuildShowsTheVersion(using harness: TestHarness) {
        let identity = BuildIdentity.resolve(
            shortVersion: "0.4.0",
            gitCommit: nil,
            hasUncommittedChanges: false
        )
        harness.expectEqual(identity.source, .release(version: "0.4.0"), "no commit means release")
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .en)),
            "v0.4.0",
            "release text carries the version"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .zh)),
            "v0.4.0",
            "release text is language independent"
        )
    }

    private static func testMissingValuesDegradeGracefully(using harness: TestHarness) {
        harness.expectEqual(
            BuildIdentity.resolve(shortVersion: nil, gitCommit: nil, hasUncommittedChanges: false).source,
            .release(version: "-"),
            "missing version still resolves to a release identity"
        )
        harness.expectEqual(
            BuildIdentity.resolve(shortVersion: "0.4.0", gitCommit: "   ", hasUncommittedChanges: false).source,
            .release(version: "0.4.0"),
            "blank commit is ignored"
        )
        harness.expectEqual(
            BuildIdentity.resolve(shortVersion: "0.4.0", gitCommit: " abc1234 ", hasUncommittedChanges: false).source,
            .development(commit: "abc1234", hasUncommittedChanges: false),
            "commit is trimmed"
        )
    }

    private static func testDevelopmentBuildNeverReportsAVersion(using harness: TestHarness) {
        // The whole point: an unreleased build must not be quotable as "0.3.16".
        let identity = BuildIdentity.resolve(
            shortVersion: "0.3.16",
            gitCommit: "9901c65",
            hasUncommittedChanges: false
        )
        let text = identity.displayText(using: LocalizedStrings(language: .en))
        harness.expectTrue(!text.contains("0.3.16"), "development build hides any version number")
        harness.expectTrue(text.contains("9901c65"), "development build still names the commit")
    }
}
