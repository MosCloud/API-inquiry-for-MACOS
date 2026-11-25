import APIInquiryCore

enum BuildIdentityTests {
    static func run(using harness: TestHarness) {
        testDevelopmentBuildIdentifiesTheCommit(using: harness)
        testDevelopmentBuildCarriesTheVersionWithADevSuffix(using: harness)
        testDirtyDevelopmentBuildSaysSo(using: harness)
        testReleaseBuildShowsTheVersion(using: harness)
        testMissingValuesDegradeGracefully(using: harness)
        testDevelopmentBuildNeverPassesForTheRelease(using: harness)
        testDevelopmentCommitIsExposedOnlyForDevelopmentBuilds(using: harness)
    }

    private static func testDevelopmentBuildIdentifiesTheCommit(using harness: TestHarness) {
        let identity = BuildIdentity.resolve(
            shortVersion: "0.0.0-dev",
            gitCommit: "9901c65",
            hasUncommittedChanges: false
        )
        harness.expectEqual(
            identity.source,
            .development(version: "0.0.0-dev", commit: "9901c65", hasUncommittedChanges: false),
            "commit marks the build as development"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .en)),
            "Development version 0.0.0-dev · commit 9901c65",
            "english development text names the version and the commit"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .zh)),
            "开发版本 0.0.0-dev · 提交 9901c65",
            "chinese development text names the version and the commit"
        )
    }


    private static func testDevelopmentCommitIsExposedOnlyForDevelopmentBuilds(using harness: TestHarness) {
        let development = BuildIdentity.resolve(
            shortVersion: "0.0.0-dev",
            gitCommit: "abc1234",
            hasUncommittedChanges: false
        )
        harness.expectEqual(development.developmentCommit, "abc1234", "development commit is exposed")

        let dirty = BuildIdentity.resolve(
            shortVersion: "0.0.0-dev",
            gitCommit: "abc1234",
            hasUncommittedChanges: true
        )
        harness.expectEqual(dirty.developmentCommit, "abc1234", "dirty development build still exposes the commit")

        let release = BuildIdentity.resolve(
            shortVersion: "0.4.0",
            gitCommit: nil,
            hasUncommittedChanges: false
        )
        harness.expectEqual(release.developmentCommit, nil, "release builds expose no commit")
    }

    private static func testDirtyDevelopmentBuildSaysSo(using harness: TestHarness) {
        let identity = BuildIdentity.resolve(
            shortVersion: "0.0.0-dev",
            gitCommit: "9901c65",
            hasUncommittedChanges: true
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .en)),
            "Development version 0.0.0-dev · commit 9901c65 + dirty",
            "english dirty suffix"
        )
        harness.expectEqual(
            identity.displayText(using: LocalizedStrings(language: .zh)),
            "开发版本 0.0.0-dev · 提交 9901c65 + 改动",
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
            .development(version: "0.4.0-dev", commit: "abc1234", hasUncommittedChanges: false),
            "commit is trimmed"
        )
    }

    private static func testDevelopmentBuildNeverPassesForTheRelease(using harness: TestHarness) {
        // A development build now says which release it came from, so it has to carry the
        // `-dev` suffix no matter what the plist says: "0.3.16" beside a commit would be
        // quotable as the release, which is what this whole type exists to prevent.
        let unmarked = BuildIdentity.resolve(
            shortVersion: "0.3.16",
            gitCommit: "9901c65",
            hasUncommittedChanges: false
        )
        harness.expectEqual(
            unmarked.source,
            .development(version: "0.3.16-dev", commit: "9901c65", hasUncommittedChanges: false),
            "an unmarked version gains the dev suffix"
        )
        let text = unmarked.displayText(using: LocalizedStrings(language: .en))
        harness.expectTrue(text.contains("0.3.16-dev"), "the version is shown, marked as development")
        harness.expectTrue(text.contains("9901c65"), "development build still names the commit")

        // The suffix is not doubled when the plist already carries one.
        let marked = BuildIdentity.resolve(
            shortVersion: "0.4.4-dev",
            gitCommit: "9901c65",
            hasUncommittedChanges: false
        )
        harness.expectEqual(
            marked.source,
            .development(version: "0.4.4-dev", commit: "9901c65", hasUncommittedChanges: false),
            "an already marked version is left alone"
        )
    }

    /// The version a development build advertises, so a copy in someone's hands can be
    /// identified without opening the bundle.
    private static func testDevelopmentBuildCarriesTheVersionWithADevSuffix(using harness: TestHarness) {
        let local = BuildIdentity.resolve(
            shortVersion: "0.4.4-dev",
            gitCommit: "597247a",
            hasUncommittedChanges: false
        )
        harness.expectEqual(local.developmentVersion, "0.4.4-dev", "development version is exposed")
        harness.expectEqual(
            local.displayText(using: LocalizedStrings(language: .zh)),
            "开发版本 0.4.4-dev · 提交 597247a",
            "chinese copy names the version it was cut from"
        )

        let release = BuildIdentity.resolve(
            shortVersion: "0.4.4",
            gitCommit: nil,
            hasUncommittedChanges: false
        )
        harness.expectEqual(release.developmentVersion, nil, "release builds expose no development version")
    }
}
