import Foundation

/// How a build identifies itself.
///
/// A development build advertises the version it was cut from *with a `-dev` suffix*
/// ("0.4.4-dev") plus the commit it was built at. The suffix is the contract: it keeps the
/// number from being quotable as the release, while still telling whoever has the copy
/// which release it came from — a placeholder like "0.0.0-dev" threw that away.
public struct BuildIdentity: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case development(version: String, commit: String, hasUncommittedChanges: Bool)
        case release(version: String)
    }

    public let source: Source

    public init(source: Source) {
        self.source = source
    }

    /// Builds an identity from the values the packaging scripts write into Info.plist.
    ///
    /// The presence of `APIInquiryGitCommit` is what marks a build as a development
    /// build; release packaging removes it.
    public static func resolve(
        shortVersion: String?,
        gitCommit: String?,
        hasUncommittedChanges: Bool
    ) -> BuildIdentity {
        let commit = gitCommit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !commit.isEmpty {
            return BuildIdentity(
                source: .development(
                    version: developmentVersion(from: shortVersion),
                    commit: commit,
                    hasUncommittedChanges: hasUncommittedChanges
                )
            )
        }

        let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return BuildIdentity(source: .release(version: version.isEmpty ? "-" : version))
    }

    /// The `-dev` version a development build advertises, `nil` for release builds.
    ///
    /// Normalised here rather than at the call site: a plist that already says `-dev` keeps
    /// one suffix, and one that does not gains exactly one — so the guarantee holds even if
    /// a build script forgets.
    public var developmentVersion: String? {
        guard case let .development(version, _, _) = source else {
            return nil
        }
        return version
    }

    /// The commit behind a development build, `nil` for release builds.
    public var developmentCommit: String? {
        guard case let .development(_, commit, _) = source else {
            return nil
        }
        return commit
    }

    /// Force the development suffix, keeping any that is already there.
    private static func developmentVersion(from shortVersion: String?) -> String {
        let raw = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = raw.isEmpty ? "-" : raw
        return base.hasSuffix(developmentSuffix) ? base : base + developmentSuffix
    }

    /// The marker that keeps a development build from being quotable as the release.
    public static let developmentSuffix = "-dev"

    public func displayText(using strings: LocalizedStrings) -> String {
        switch source {
        case let .development(version, commit, hasUncommittedChanges):
            var text = "\(strings.developmentVersionPrefix) \(version) \(strings.developmentCommitSeparator) \(commit)"
            if hasUncommittedChanges {
                text += " \(strings.developmentVersionDirtySuffix)"
            }
            return text
        case let .release(version):
            return "v\(version)"
        }
    }
}
