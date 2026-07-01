import APIInquiryCore
import Foundation

enum CodexManualResetCreditsProviderTests {
    static func run(using harness: TestHarness) async {
        await testFetchSnapshotBuildsRequestAndParsesCredits(using: harness)
        await testEnvelopeCreditsAreAlsoAccepted(using: harness)
        await testAuthenticationFailureMapsToProviderError(using: harness)
        await testForbiddenMapsToAuthenticationFailure(using: harness)
        await testRateLimitMapsToProviderError(using: harness)
        await testMalformedJSONMapsToDecodingFailure(using: harness)
        await testMissingCreditsMapsToMissingBalanceInfo(using: harness)
    }

    private static func testFetchSnapshotBuildsRequestAndParsesCredits(using harness: TestHarness) async {
        let fetchedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let firstGrantedAt = isoDate("2026-06-18T00:35:47Z")
        let firstExpiresAt = isoDate("2026-07-18T00:35:47Z")
        let secondGrantedAt = isoDate("2026-06-27T00:44:20Z")
        let secondExpiresAt = isoDate("2026-07-27T00:44:20Z")
        let secondRedeemedAt = isoDate("2026-06-30T00:00:00Z")
        let httpClient = CodexManualResetMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "credits": [
                {"granted_at":"2026-06-18T00:35:47Z","expires_at":"2026-07-18T00:35:47Z","redeemed_at":null},
                {"granted_at":"2026-06-27T00:44:20Z","expires_at":"2026-07-27T00:44:20Z","redeemed_at":"2026-06-30T00:00:00Z"}
              ]
            }
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = CodexManualResetCreditsProvider(httpClient: httpClient, now: { fetchedAt })

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "Bearer test-token")
            harness.expectEqual(snapshot.credits.count, 2, "manual reset credits parsed")
            harness.expectEqual(snapshot.fetchedAt, fetchedAt, "manual reset fetched at")
            harness.expectEqual(
                snapshot.credits.first,
                CodexManualResetCredit(grantedAt: firstGrantedAt, expiresAt: firstExpiresAt, redeemedAt: nil),
                "manual reset first credit"
            )
            harness.expectEqual(
                snapshot.credits.last,
                CodexManualResetCredit(
                    grantedAt: secondGrantedAt,
                    expiresAt: secondExpiresAt,
                    redeemedAt: secondRedeemedAt
                ),
                "manual reset second credit"
            )
            harness.expectEqual(
                httpClient.lastRequest?.url,
                URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!,
                "manual reset endpoint"
            )
            harness.expectEqual(httpClient.lastRequest?.httpMethod, "GET", "manual reset method")
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-token",
                "manual reset authorization"
            )
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Accept"),
                "application/json",
                "manual reset accept header"
            )
        } catch {
            harness.expectTrue(false, "manual reset fetch should not throw: \(error)")
        }
    }

    private static func testEnvelopeCreditsAreAlsoAccepted(using harness: TestHarness) async {
        let provider = CodexManualResetCreditsProvider(httpClient: CodexManualResetMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "payload": {
                "credits": [
                  {"granted_at":"2026-06-18T00:35:47Z","expires_at":"2026-07-18T00:35:47Z","redeemed_at":null}
                ]
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )))

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "test-token")
            harness.expectEqual(snapshot.credits.count, 1, "manual reset envelope credits parsed")
        } catch {
            harness.expectTrue(false, "manual reset envelope parse should not throw: \(error)")
        }
    }

    private static func testAuthenticationFailureMapsToProviderError(using harness: TestHarness) async {
        let provider = CodexManualResetCreditsProvider(httpClient: CodexManualResetMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401)))

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "bad-token")
        }, "manual reset 401 maps to authenticationFailed")
    }

    private static func testForbiddenMapsToAuthenticationFailure(using harness: TestHarness) async {
        let provider = CodexManualResetCreditsProvider(httpClient: CodexManualResetMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 403)))

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "bad-token")
        }, "manual reset 403 maps to authenticationFailed")
    }

    private static func testRateLimitMapsToProviderError(using harness: TestHarness) async {
        let provider = CodexManualResetCreditsProvider(httpClient: CodexManualResetMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429)))

        await harness.expectThrowsBalanceProviderError(.rateLimited, {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "manual reset 429 maps to rateLimited")
    }

    private static func testMalformedJSONMapsToDecodingFailure(using harness: TestHarness) async {
        let provider = CodexManualResetCreditsProvider(httpClient: CodexManualResetMockHTTPClient(response: HTTPResponse(
            data: "{".data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.decodingFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "manual reset malformed json maps to decodingFailed")
    }

    private static func testMissingCreditsMapsToMissingBalanceInfo(using harness: TestHarness) async {
        let provider = CodexManualResetCreditsProvider(httpClient: CodexManualResetMockHTTPClient(response: HTTPResponse(
            data: #"{"payload":{}}"#.data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.missingBalanceInfo, {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "manual reset missing credits maps to missingBalanceInfo")
    }

    private static func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

private final class CodexManualResetMockHTTPClient: HTTPClient {
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
