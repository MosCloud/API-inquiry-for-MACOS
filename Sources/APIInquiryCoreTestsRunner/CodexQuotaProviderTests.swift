import APIInquiryCore
import Foundation

enum CodexQuotaProviderTests {
    static func run(using harness: TestHarness) async {
        await testRawTokenRequestAndQuotaParsing(using: harness)
        await testBearerTokenIsNormalized(using: harness)
        await testAuthJSONExtractsTokenAndAccountID(using: harness)
        await testResetAfterSecondsIsUsedWhenResetAtIsMissing(using: harness)
        await testNullResetFieldsAreIgnored(using: harness)
        await testPlanNameNormalization(using: harness)
        await testAuthenticationFailureMapsToProviderError(using: harness)
        await testForbiddenMapsToAuthenticationFailure(using: harness)
        await testRateLimitMapsToProviderError(using: harness)
        await testServerErrorMapsToProviderError(using: harness)
        await testMalformedJSONMapsToDecodingFailure(using: harness)
        await testMissingQuotaWindowsMapsToMissingBalanceInfo(using: harness)
    }

    private static func testRawTokenRequestAndQuotaParsing(using harness: TestHarness) async {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_000_000)
        let primaryReset = Date(timeIntervalSince1970: 1_715_003_600)
        let secondaryReset = Date(timeIntervalSince1970: 1_715_604_800)
        let httpClient = CodexMockHTTPClient(response: HTTPResponse(
            data: usageResponseData(
                planType: "plus",
                primaryUsedPercent: 28,
                primaryResetAt: Int(primaryReset.timeIntervalSince1970),
                secondaryUsedPercent: 52,
                secondaryResetAt: Int(secondaryReset.timeIntervalSince1970)
            ),
            statusCode: 200
        ))
        let provider = CodexQuotaProvider(httpClient: httpClient, now: { fetchedAt })

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "test-token")

            switch snapshot {
            case .quotaUsage(let usage):
                harness.expectEqual(usage.providerID, .codex, "codex provider id")
                harness.expectEqual(usage.planName, "Plus", "codex plan name")
                harness.expectEqual(usage.windows.count, 2, "codex quota window count")
                harness.expectEqual(usage.windows.first?.label, "5h", "codex primary label")
                harness.expectEqual(usage.windows.first?.remainingPercentage, Decimal(72), "codex primary remaining")
                harness.expectEqual(usage.windows.first?.resetAt, primaryReset, "codex primary reset")
                harness.expectTrue(usage.windows.first?.isAvailable == true, "codex primary available")
                harness.expectEqual(usage.windows.last?.label, "Week", "codex secondary label")
                harness.expectEqual(usage.windows.last?.remainingPercentage, Decimal(48), "codex secondary remaining")
                harness.expectEqual(usage.windows.last?.resetAt, secondaryReset, "codex secondary reset")
                harness.expectEqual(usage.fetchedAt, fetchedAt, "codex fetched at")
            case .balance, .planUsage:
                harness.expectTrue(false, "codex snapshot should be quota usage")
            }

            harness.expectEqual(
                httpClient.lastRequest?.url,
                URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
                "codex usage request url"
            )
            harness.expectEqual(httpClient.lastRequest?.httpMethod, "GET", "codex usage request method")
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-token",
                "codex authorization header"
            )
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Accept"),
                "application/json",
                "codex accept header"
            )
        } catch {
            harness.expectTrue(false, "codex usage should not throw: \(error)")
        }
    }

    private static func testBearerTokenIsNormalized(using harness: TestHarness) async {
        let httpClient = CodexMockHTTPClient(response: HTTPResponse(data: usageResponseData(), statusCode: 200))
        let provider = CodexQuotaProvider(httpClient: httpClient)

        _ = try? await provider.fetchSnapshot(apiKey: "Bearer test-token")

        harness.expectEqual(
            httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer test-token",
            "codex bearer input is normalized"
        )
    }

    private static func testAuthJSONExtractsTokenAndAccountID(using harness: TestHarness) async {
        let httpClient = CodexMockHTTPClient(response: HTTPResponse(data: usageResponseData(), statusCode: 200))
        let provider = CodexQuotaProvider(httpClient: httpClient)
        let credential = """
        {
          "tokens": {
            "access_token": "json-token",
            "account_id": "account-123"
          }
        }
        """

        _ = try? await provider.fetchSnapshot(apiKey: credential)

        harness.expectEqual(
            httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "Bearer json-token",
            "codex auth json authorization header"
        )
        harness.expectEqual(
            httpClient.lastRequest?.value(forHTTPHeaderField: "ChatGPT-Account-Id"),
            "account-123",
            "codex account id header"
        )
    }

    private static func testResetAfterSecondsIsUsedWhenResetAtIsMissing(using harness: TestHarness) async {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_000_000)
        let httpClient = CodexMockHTTPClient(response: HTTPResponse(
            data: usageResponseData(primaryResetAt: nil, primaryResetAfterSeconds: 120),
            statusCode: 200
        ))
        let provider = CodexQuotaProvider(httpClient: httpClient, now: { fetchedAt })

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "test-token")
            let resetAt = snapshot.lastQuotaWindow(label: "5h")?.resetAt

            harness.expectEqual(
                resetAt,
                Date(timeInterval: 120, since: fetchedAt),
                "codex reset_after_seconds fallback"
            )
        } catch {
            harness.expectTrue(false, "codex reset_after_seconds should not throw: \(error)")
        }
    }

    private static func testNullResetFieldsAreIgnored(using harness: TestHarness) async {
        let httpClient = CodexMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "plan_type": "plus",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 16,
                  "limit_window_seconds": 18000,
                  "reset_at": null,
                  "reset_after_seconds": null
                },
                "secondary_window": {
                  "used_percent": 1,
                  "limit_window_seconds": 604800,
                  "reset_at": null
                }
              }
            }
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = CodexQuotaProvider(httpClient: httpClient)

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "test-token")
            harness.expectEqual(snapshot.lastQuotaWindow(label: "5h")?.resetAt, nil, "codex null primary reset ignored")
            harness.expectEqual(snapshot.lastQuotaWindow(label: "Week")?.resetAt, nil, "codex null secondary reset ignored")
        } catch {
            harness.expectTrue(false, "codex null reset fields should not throw: \(error)")
        }
    }

    private static func testPlanNameNormalization(using harness: TestHarness) async {
        let cases = [
            ("free", "Free"),
            ("plus", "Plus"),
            ("pro_5x", "Pro 5x"),
            ("pro_20x", "Pro 20x"),
            ("business", "Business"),
            ("enterprise", "Enterprise/Edu")
        ]

        for (rawPlan, expectedPlan) in cases {
            let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(
                data: usageResponseData(planType: rawPlan),
                statusCode: 200
            )))

            do {
                let snapshot = try await provider.fetchSnapshot(apiKey: "test-token")
                harness.expectEqual(snapshot.lastQuotaUsageSnapshot?.planName, expectedPlan, "codex plan \(rawPlan)")
            } catch {
                harness.expectTrue(false, "codex plan normalization should not throw: \(error)")
            }
        }
    }

    private static func testAuthenticationFailureMapsToProviderError(using harness: TestHarness) async {
        let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401)))

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "bad-token")
        }, "codex 401 maps to authenticationFailed")
    }

    private static func testForbiddenMapsToAuthenticationFailure(using harness: TestHarness) async {
        let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 403)))

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "bad-token")
        }, "codex 403 maps to authenticationFailed")
    }

    private static func testRateLimitMapsToProviderError(using harness: TestHarness) async {
        let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429)))

        await harness.expectThrowsBalanceProviderError(.rateLimited, {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "codex 429 maps to rateLimited")
    }

    private static func testServerErrorMapsToProviderError(using harness: TestHarness) async {
        let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 500)))

        await harness.expectThrowsBalanceProviderError(.serverError(statusCode: 500), {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "codex 500 maps to serverError")
    }

    private static func testMalformedJSONMapsToDecodingFailure(using harness: TestHarness) async {
        let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(
            data: "{".data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.decodingFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "codex malformed json maps to decodingFailed")
    }

    private static func testMissingQuotaWindowsMapsToMissingBalanceInfo(using harness: TestHarness) async {
        let provider = CodexQuotaProvider(httpClient: CodexMockHTTPClient(response: HTTPResponse(
            data: #"{"plan_type":"plus","rate_limit":{}}"#.data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.missingBalanceInfo, {
            _ = try await provider.fetchSnapshot(apiKey: "test-token")
        }, "codex missing windows maps to missingBalanceInfo")
    }

    private static func usageResponseData(
        planType: String = "plus",
        primaryUsedPercent: Int = 28,
        primaryResetAt: Int? = 1_715_003_600,
        primaryResetAfterSeconds: Int? = nil,
        secondaryUsedPercent: Int = 52,
        secondaryResetAt: Int? = 1_715_604_800
    ) -> Data {
        let primaryResetLine = primaryResetAt.map { #","reset_at": \#($0)"# } ?? ""
        let primaryResetAfterLine = primaryResetAfterSeconds.map { #","reset_after_seconds": \#($0)"# } ?? ""
        let secondaryResetLine = secondaryResetAt.map { #","reset_at": \#($0)"# } ?? ""
        return """
        {
          "plan_type": "\(planType)",
          "rate_limit": {
            "primary_window": {
              "used_percent": \(primaryUsedPercent),
              "limit_window_seconds": 18000\(primaryResetLine)\(primaryResetAfterLine)
            },
            "secondary_window": {
              "used_percent": \(secondaryUsedPercent),
              "limit_window_seconds": 604800\(secondaryResetLine)
            }
          }
        }
        """.data(using: .utf8)!
    }
}

private extension ProviderSnapshot {
    var lastQuotaUsageSnapshot: QuotaUsageSnapshot? {
        guard case .quotaUsage(let snapshot) = self else {
            return nil
        }
        return snapshot
    }

    func lastQuotaWindow(label: String) -> QuotaWindowSnapshot? {
        lastQuotaUsageSnapshot?.windows.first { $0.label == label }
    }
}

private final class CodexMockHTTPClient: HTTPClient {
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
