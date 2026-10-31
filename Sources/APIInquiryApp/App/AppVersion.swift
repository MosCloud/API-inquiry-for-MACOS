import APIInquiryCore
import Foundation

enum AppVersion {
    /// Resolved once from the bundle: development builds carry `APIInquiryGitCommit`
    /// (written by the local build script), release builds carry a real version number.
    static let identity = BuildIdentity.resolve(
        shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        gitCommit: Bundle.main.object(forInfoDictionaryKey: "APIInquiryGitCommit") as? String,
        hasUncommittedChanges: Bundle.main.object(forInfoDictionaryKey: "APIInquiryGitDirty") as? Bool ?? false
    )
}
