import Foundation

/// How a build identifies itself.
///
/// A version number exists only in release artifacts. Development builds carry the git
/// commit instead, so a build from `main` can never claim to be "0.3.16" — that
/// ambiguity used to cost real debugging time when a stale copy was installed.
public struct BuildIdentity: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case development(commit: String, hasUncommittedChanges: Bool)
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
                source: .development(commit: commit, hasUncommittedChanges: hasUncommittedChanges)
            )
        }

        let version = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return BuildIdentity(source: .release(version: version.isEmpty ? "-" : version))
    }

    public func displayText(using strings: LocalizedStrings) -> String {
        switch source {
        case let .development(commit, hasUncommittedChanges):
            var text = "\(strings.developmentVersionPrefix) \(commit)"
            if hasUncommittedChanges {
                text += " \(strings.developmentVersionDirtySuffix)"
            }
            return text
        case let .release(version):
            return "v\(version)"
        }
    }
}
