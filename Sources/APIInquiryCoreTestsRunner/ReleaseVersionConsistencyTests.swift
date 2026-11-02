import Foundation

enum ReleaseVersionConsistencyTests {
    static func run(using harness: TestHarness) {
        let root = repositoryRoot()
        let versionEnvPath = root.appendingPathComponent("Scripts").appendingPathComponent("version.env")
        let localBuildPath = root.appendingPathComponent("Scripts").appendingPathComponent("build-local-app.sh")
        let packagePath = root.appendingPathComponent("Scripts").appendingPathComponent("package-mac-app.sh")
        let layoutPath = root.appendingPathComponent("Scripts").appendingPathComponent("dmg-layout.env")
        let backgroundGeneratorPath = root
            .appendingPathComponent("Scripts")
            .appendingPathComponent("generate-dmg-background.swift")

        let versionEnv = (try? String(contentsOf: versionEnvPath, encoding: .utf8)) ?? ""
        let localBuild = (try? String(contentsOf: localBuildPath, encoding: .utf8)) ?? ""
        let package = (try? String(contentsOf: packagePath, encoding: .utf8)) ?? ""
        let layout = (try? String(contentsOf: layoutPath, encoding: .utf8)) ?? ""

        // The file is the single source of truth, so check that it agrees with itself
        // rather than pinning one release number here (#44).
        let values = parseVersionEnv(versionEnv)
        let version = values["APP_VERSION"] ?? ""

        harness.expectTrue(!version.isEmpty, "version.env declares APP_VERSION")
        harness.expectEqual(values["RELEASE_VERSION"], version, "release version matches the app version")
        harness.expectEqual(values["RELEASE_TAG"], "release/v\(version)", "release tag matches the app version")
        harness.expectEqual(values["DMG_BASENAME"], "API-Inquiry-v\(version)", "dmg basename matches the app version")
        harness.expectEqual(values["DMG_BASENAME_EN"], "API-Inquiry-v\(version)-en", "english dmg basename matches the app version")
        harness.expectEqual(values["VOLUME_NAME"], "API Inquiry v\(version)", "volume name matches the app version")
        harness.expectTrue(
            (Int(values["BUILD_NUMBER"] ?? "") ?? 0) > 0,
            "build number is a positive integer"
        )

        // Two languages ship side by side (#107), so the window geometry lives in
        // one file that both the background generator and package-dmg.sh read.
        // A second copy is how the arrow ended up 9.5 pt off the icon midpoint.
        let layoutValues = parseVersionEnv(layout)
        let requiredLayoutKeys = [
            "DMG_WINDOW_WIDTH", "DMG_WINDOW_HEIGHT", "DMG_WINDOW_LEFT", "DMG_WINDOW_TOP",
            "DMG_ICON_SIZE", "DMG_APP_ICON_X", "DMG_APP_ICON_Y", "DMG_FOLDER_ICON_X", "DMG_FOLDER_ICON_Y"
        ]
        let missingLayoutKeys = requiredLayoutKeys.filter { (layoutValues[$0] ?? "").isEmpty }
        harness.expectTrue(
            missingLayoutKeys.isEmpty,
            "dmg-layout.env declares the shared window geometry (missing: \(missingLayoutKeys.joined(separator: ", ")))"
        )
        harness.expectTrue(
            FileManager.default.fileExists(atPath: backgroundGeneratorPath.path),
            "the DMG background generator is present"
        )

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

    private static func parseVersionEnv(_ contents: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let separator = trimmed.firstIndex(of: "=") else {
                continue
            }
            let key = String(trimmed[..<separator])
            let rawValue = String(trimmed[trimmed.index(after: separator)...])
            values[key] = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return values
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
