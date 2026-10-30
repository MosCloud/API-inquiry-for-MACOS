import APIInquiryCore
import Foundation

enum OpenCodeGoUsageProviderTests {
    static func run(using harness: TestHarness) async {
        await testLivePayloadMapsThreeWindows(using: harness)
        await testRateLimitedMeterIsUnavailable(using: harness)
        await testFullUsageLeavesNoRemainingAllowance(using: harness)
        await testStringPercentIsAccepted(using: harness)
        await testUnauthorizedMapsToAuthenticationFailed(using: harness)
        await testForbiddenMapsToSubscriptionRequired(using: harness)
        await testRateLimitStatusMapsToRateLimited(using: harness)
        await testServerErrorMapsToServerError(using: harness)
        await testMalformedPayloadMapsToDecodingFailed(using: harness)
        await testRequestCarriesBearerTokenAndUserAgent(using: harness)
    }

    private static func testLivePayloadMapsThreeWindows(using harness: TestHarness) async {
        let httpClient = OpenCodeMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "usage": {
                "rolling": {"status": "ok", "percent": 6, "resetsAt": "2026-10-30T11:27:01.000Z"},
                "weekly": {"status": "ok", "percent": 34.5, "resetsAt": "2026-11-02T00:00:00.000Z"},
                "monthly": {"status": "ok", "percent": 12, "resetsAt": "2026-11-30T06:18:06.000Z"}
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = OpenCodeGoUsageProvider(httpClient: httpClient)

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "opencode-key")
            guard case .quotaUsage(let usage) = snapshot else {
                harness.expectTrue(false, "opencode snapshot should be quota usage")
                return
            }
            harness.expectEqual(usage.providerID, .opencode, "opencode provider id")
            harness.expectEqual(usage.planName, "OpenCode Go", "opencode plan name")
            harness.expectEqual(usage.windows.count, 3, "opencode exposes three windows")
            harness.expectEqual(usage.windows.map(\.label), ["5h", "Week", "Month"], "opencode window labels")
            harness.expectEqual(usage.windows.map(\.kind), [.fiveHour, .week, .month], "opencode window kinds")
            harness.expectEqual(
                usage.windows.map(\.remainingPercentage),
                [Decimal(94), Decimal(65.5), Decimal(88)],
                "opencode windows convert used percent into remaining percent"
            )
            harness.expectEqual(usage.windows.first?.resetAt != nil, true, "opencode keeps rolling reset date")
            harness.expectEqual(usage.windows.first?.isAvailable, true, "opencode rolling window available")
        } catch {
            harness.expectTrue(false, "opencode usage should not throw: \(error)")
        }
    }

    private static func testRateLimitedMeterIsUnavailable(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "usage": {
                "rolling": {"status": "rate-limited", "percent": 100, "resetsAt": "2026-10-30T11:27:01.000Z"},
                "weekly": {"status": "ok", "percent": 10, "resetsAt": "2026-11-02T00:00:00.000Z"},
                "monthly": {"status": "ok", "percent": 4, "resetsAt": "2026-11-30T06:18:06.000Z"}
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )))

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "opencode-key")
            let usage = snapshot.openCodeQuotaSnapshot
            harness.expectEqual(usage?.windows.first?.remainingPercentage, 0, "rate limited window has no remaining allowance")
            harness.expectEqual(usage?.windows.first?.isAvailable, false, "rate limited window is unavailable")
            harness.expectEqual(usage?.isAvailable, true, "other windows keep the provider available")
        } catch {
            harness.expectTrue(false, "rate limited payload should not throw: \(error)")
        }
    }

    private static func testFullUsageLeavesNoRemainingAllowance(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "usage": {
                "rolling": {"status": "ok", "percent": 120, "resetsAt": null},
                "weekly": {"status": "ok", "percent": 0, "resetsAt": null},
                "monthly": {"status": "ok", "percent": 0, "resetsAt": null}
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )))

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "opencode-key")
            harness.expectEqual(snapshot.openCodeQuotaSnapshot?.windows.first?.remainingPercentage, 0, "over-used percent clamps to zero remaining")
        } catch {
            harness.expectTrue(false, "over-used payload should not throw: \(error)")
        }
    }

    private static func testStringPercentIsAccepted(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "usage": {
                "rolling": {"status": "ok", "percent": "25.5", "resetsAt": "2026-10-30T11:27:01Z"},
                "weekly": {"status": "ok", "percent": "0", "resetsAt": null},
                "monthly": {"status": "ok", "percent": 0, "resetsAt": null}
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )))

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "opencode-key")
            harness.expectEqual(snapshot.openCodeQuotaSnapshot?.windows.first?.remainingPercentage, Decimal(74.5), "string percent is accepted")
        } catch {
            harness.expectTrue(false, "string percent payload should not throw: \(error)")
        }
    }

    private static func testUnauthorizedMapsToAuthenticationFailed(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401)))
        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "opencode-key")
        }, "opencode 401 maps to authentication failure")
    }

    private static func testForbiddenMapsToSubscriptionRequired(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 403)))
        await harness.expectThrowsBalanceProviderError(.subscriptionRequired, {
            _ = try await provider.fetchSnapshot(apiKey: "opencode-key")
        }, "opencode 403 maps to missing subscription")
    }

    private static func testRateLimitStatusMapsToRateLimited(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429)))
        await harness.expectThrowsBalanceProviderError(.rateLimited, {
            _ = try await provider.fetchSnapshot(apiKey: "opencode-key")
        }, "opencode 429 maps to rate limited")
    }

    private static func testServerErrorMapsToServerError(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 502)))
        await harness.expectThrowsBalanceProviderError(.serverError(statusCode: 502), {
            _ = try await provider.fetchSnapshot(apiKey: "opencode-key")
        }, "opencode 502 maps to server error")
    }

    private static func testMalformedPayloadMapsToDecodingFailed(using harness: TestHarness) async {
        let provider = OpenCodeGoUsageProvider(httpClient: OpenCodeMockHTTPClient(response: HTTPResponse(
            data: #"{"usage":{"rolling":{"status":"ok"}}}"#.data(using: .utf8)!,
            statusCode: 200
        )))
        await harness.expectThrowsBalanceProviderError(.decodingFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "opencode-key")
        }, "opencode malformed payload maps to decoding failure")
    }

    private static func testRequestCarriesBearerTokenAndUserAgent(using harness: TestHarness) async {
        let httpClient = OpenCodeMockHTTPClient(response: HTTPResponse(
            data: """
            {"usage":{"rolling":{"status":"ok","percent":0,"resetsAt":null},"weekly":{"status":"ok","percent":0,"resetsAt":null},"monthly":{"status":"ok","percent":0,"resetsAt":null}}}
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = OpenCodeGoUsageProvider(httpClient: httpClient)

        do {
            _ = try await provider.fetchSnapshot(apiKey: "  opencode-key\n")
            harness.expectEqual(
                httpClient.lastRequest?.url?.absoluteString,
                "https://opencode.ai/zen/go/v1/usage",
                "opencode usage url"
            )
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                "Bearer opencode-key",
                "opencode bearer token is trimmed"
            )
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Accept"),
                "application/json",
                "opencode accept header"
            )
            harness.expectTrue(
                httpClient.lastRequest?.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("API-Inquiry/") == true,
                "opencode sends its own user agent"
            )
        } catch {
            harness.expectTrue(false, "opencode request should not throw: \(error)")
        }
    }
}

private extension ProviderSnapshot {
    var openCodeQuotaSnapshot: QuotaUsageSnapshot? {
        guard case .quotaUsage(let snapshot) = self else {
            return nil
        }
        return snapshot
    }
}

private final class OpenCodeMockHTTPClient: HTTPClient {
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
