import APIInquiryCore
import Foundation

/// S3: decodes `RetrieveUserQuotaSummary` into a single-week-window snapshot.
///
/// The recorded payload mirrors the live shape measured against Antigravity 2.35.2, including
/// the `Claude and GPT models` group whose buckets carry no `resetTime` at all — the negative
/// assertions below are what keep this version's scope honest.
enum AntigravityQuotaProviderTests {
    static func run(using harness: TestHarness) async {
        await testDecodesGeminiWeeklyWindow(using: harness)
        await testIgnoresThirdPartyGroup(using: harness)
        await testIgnoresUnknownCadence(using: harness)
        await testMissingGroupsIsMissingBalanceInfo(using: harness)
        await testMissingGeminiGroupIsMissingBalanceInfo(using: harness)
        await testUnauthorizedIsNotSignedIn(using: harness)
        await testNotFoundIsVersionChanged(using: harness)
        await testSendsSessionHeaders(using: harness)
    }

    private static func testDecodesGeminiWeeklyWindow(using harness: TestHarness) async {
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: recordedSummary.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            let usage = quotaUsage(snapshot)

            harness.expectEqual(usage?.windows.count, 1, "antigravity reports one window in this version")
            harness.expectEqual(usage?.windows.first?.label, "Week", "antigravity weekly label is canonical")
            harness.expectEqual(usage?.windows.first?.kind, .week, "antigravity weekly kind is week")
            harness.expectEqual(
                usage?.windows.first?.remainingPercentage,
                Decimal(string: "55.08368"),
                "antigravity converts remainingFraction to a remaining percentage"
            )
            harness.expectEqual(
                usage?.windows.first.map { ProviderDisplayFormatter.quotaWindowAmountText(for: $0) },
                "55",
                "antigravity renders the measured 55% the panel shows"
            )
            harness.expectTrue(usage?.windows.first?.resetAt != nil, "antigravity weekly window carries a reset date")
            // 2026-12-03T15:13:43Z as a Unix timestamp, so the assertion needs no internal API.
            harness.expectEqual(
                usage?.windows.first?.resetAt,
                Date(timeIntervalSince1970: 1_796_310_823),
                "antigravity parses the provided resetTime"
            )
            harness.expectEqual(usage?.planName, "Antigravity", "antigravity plan name")
            harness.expectEqual(usage?.fetchedAt, fixedNow, "antigravity stamps the fetch time")
        } catch {
            harness.expectTrue(false, "antigravity summary should decode: \(error)")
        }
    }

    /// The scope guard: the third-party group is in the payload and must not reach the panel.
    private static func testIgnoresThirdPartyGroup(using harness: TestHarness) async {
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: recordedSummary.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            let windows = quotaUsage(snapshot)?.windows ?? []

            harness.expectTrue(
                !windows.contains { $0.label == "5h" },
                "antigravity omits the third-party five-hour window"
            )
            harness.expectEqual(
                windows.filter { $0.kind == .week }.count,
                1,
                "antigravity reports exactly one weekly window, not the third-party one too"
            )
        } catch {
            harness.expectTrue(false, "antigravity third-party scope should decode: \(error)")
        }
    }

    /// An unrecognised cadence is skipped rather than mapped onto a known label.
    private static func testIgnoresUnknownCadence(using harness: TestHarness) async {
        let payload = """
        {"response":{"groups":[{"displayName":"Gemini Models","buckets":[
          {"bucketId":"gemini-daily","window":"daily","remainingFraction":0.5}
        ]}]}}
        """
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: payload.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            _ = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            harness.expectTrue(false, "antigravity unknown cadence should be missingBalanceInfo")
        } catch let error as BalanceProviderError {
            harness.expectEqual(error, .missingBalanceInfo, "antigravity unknown cadence is missingBalanceInfo")
        } catch {
            harness.expectTrue(false, "antigravity unknown cadence threw an unexpected error: \(error)")
        }
    }

    private static func testMissingGroupsIsMissingBalanceInfo(using harness: TestHarness) async {
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: #"{"response":{}}"#.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            _ = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            harness.expectTrue(false, "antigravity missing groups should be missingBalanceInfo")
        } catch let error as BalanceProviderError {
            harness.expectEqual(error, .missingBalanceInfo, "antigravity missing groups is missingBalanceInfo")
        } catch {
            harness.expectTrue(false, "antigravity missing groups threw an unexpected error: \(error)")
        }
    }

    private static func testMissingGeminiGroupIsMissingBalanceInfo(using harness: TestHarness) async {
        let payload = """
        {"response":{"groups":[{"displayName":"Claude and GPT models","buckets":[
          {"bucketId":"3p-weekly","window":"weekly","remainingFraction":1}
        ]}]}}
        """
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: payload.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            _ = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            harness.expectTrue(false, "antigravity missing Gemini group should be missingBalanceInfo")
        } catch let error as BalanceProviderError {
            harness.expectEqual(error, .missingBalanceInfo, "antigravity missing Gemini group is missingBalanceInfo")
        } catch {
            harness.expectTrue(false, "antigravity missing Gemini group threw an unexpected error: \(error)")
        }
    }

    private static func testUnauthorizedIsNotSignedIn(using harness: TestHarness) async {
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: Data(#"{"code":"unauthenticated","message":"unauthenticated: missing CSRF token"}"#.utf8),
            statusCode: 401
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            _ = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            harness.expectTrue(false, "antigravity 401 should throw notSignedIn")
        } catch let error as AntigravitySessionError {
            harness.expectEqual(error, .notSignedIn, "antigravity 401 is notSignedIn, not a bad key")
        } catch {
            harness.expectTrue(false, "antigravity 401 threw an unexpected error: \(error)")
        }
    }

    private static func testNotFoundIsVersionChanged(using harness: TestHarness) async {
        let client = AntigravityMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 404))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        do {
            _ = try await provider.fetchSnapshot(apiKey: fakeSessionPayload)
            harness.expectTrue(false, "antigravity 404 should throw versionChanged")
        } catch let error as AntigravitySessionError {
            harness.expectEqual(error, .versionChanged, "antigravity 404 is versionChanged")
        } catch {
            harness.expectTrue(false, "antigravity 404 threw an unexpected error: \(error)")
        }
    }

    private static func testSendsSessionHeaders(using harness: TestHarness) async {
        let client = AntigravityMockHTTPClient(response: HTTPResponse(
            data: recordedSummary.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = AntigravityQuotaProvider(
            httpClient: client,
            now: { fixedNow },
            sessionReader: AntigravitySessionReader(daemonDirectoryURL: emptyDirectory()) { _ in true }
        )

        _ = try? await provider.fetchSnapshot(apiKey: fakeSessionPayload)

        harness.expectEqual(client.lastRequest?.httpMethod, "POST", "antigravity RPC uses POST")
        harness.expectEqual(
            client.lastRequest?.value(forHTTPHeaderField: "x-codeium-csrf-token"),
            fakeCSRFToken,
            "antigravity sends the CSRF token from the session payload"
        )
        harness.expectEqual(
            client.lastRequest?.value(forHTTPHeaderField: "Connect-Protocol-Version"),
            "1",
            "antigravity sends the connect protocol version"
        )
        harness.expectTrue(
            client.lastRequest?.url?.absoluteString.hasSuffix("RetrieveUserQuotaSummary") == true,
            "antigravity targets the quota summary RPC"
        )
        harness.expectEqual(
            client.lastRequest?.url?.host,
            "127.0.0.1",
            "antigravity talks to loopback, never to a remote host"
        )
    }
}

/// Mirrors the live payload measured against Antigravity 2.35.2: one Gemini weekly bucket with
/// both fields, and a third-party group whose buckets carry no `resetTime` key at all.
private let recordedSummary = """
{"response":{"groups":[
  {"displayName":"Gemini Models","description":"Models within this group: Gemini 4 Hydrogen, Gemini 3.8 Flash","buckets":[
    {"bucketId":"gemini-weekly","displayName":"Weekly Limit Remaining","description":"You have used some of your weekly limit, it will fully refresh in 6 days, 7 hours.","window":"weekly","remainingFraction":0.5508368,"resetTime":"2026-12-03T15:13:43Z"}
  ]},
  {"displayName":"Claude and GPT models","description":"Models within this group: Claude Sonnet 4.6, Claude Opus 4.6, GPT-OSS 120B","buckets":[
    {"bucketId":"3p-weekly","displayName":"Weekly Limit Remaining","window":"weekly","remainingFraction":1},
    {"bucketId":"3p-5h","displayName":"Five Hour Limit Remaining","window":"5h","remainingFraction":1}
  ]}
]},"description":"Within each group, models share a weekly limit and a 5-hour limit."}
"""

private let fakeCSRFToken = "fake-token-00000000-0000-0000-000000"

private let fakeSessionPayload = AntigravitySessionPayload.encode(
    AntigravityLocalSession(httpPort: 63422, pid: 4242, csrfToken: fakeCSRFToken)
)

private let fixedNow = Date(timeIntervalSince1970: 1_790_000_000)

private func emptyDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "antigravity-quota-tests-empty")
}

/// `lastQuotaUsageSnapshot` is fileprivate to another test file, so unwrap the payload here.
private func quotaUsage(_ snapshot: ProviderSnapshot) -> QuotaUsageSnapshot? {
    guard case .quotaUsage(let usage) = snapshot else {
        return nil
    }
    return usage
}

private final class AntigravityMockHTTPClient: HTTPClient {
    private let response: HTTPResponse
    private(set) var lastRequest: URLRequest?

    init(response: HTTPResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPResponse {
        lastRequest = request
        return response
    }
}
