import APIInquiryCore
import Foundation

enum ZhipuCodingPlanProviderTests {
    static func run(using harness: TestHarness) async {
        await testFetchSnapshotParsesTokenLimit(using: harness)
        await testAuthenticationFailureMapsToProviderError(using: harness)
        await testRateLimitMapsToProviderError(using: harness)
        await testUsageLimitBusinessCodeMapsToProviderError(using: harness)
        await testPlanExpiredBusinessCodeMapsToProviderError(using: harness)
        await testStringBusinessCodeMapsToProviderError(using: harness)
        await testNon200BusinessCodeMapsToProviderError(using: harness)
        await testRateLimitedBusinessCodeMapsToUsageLimit(using: harness)
        await testBusinessCodeWithoutSuccessFlagMapsToProviderError(using: harness)
        await testMalformedJSONMapsToDecodingFailure(using: harness)
        await testMissingTokenLimitMapsToMissingBalanceInfo(using: harness)
    }

    private static func testNon200BusinessCodeMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: errorResponseData(code: "1309", message: "plan expired"),
            statusCode: 403
        )))

        await harness.expectThrowsBalanceProviderError(.planExpired, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu non-200 business code maps to planExpired")
    }

    private static func testRateLimitedBusinessCodeMapsToUsageLimit(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: errorResponseData(code: "1310", message: "limit reached"),
            statusCode: 429
        )))

        await harness.expectThrowsBalanceProviderError(.usageLimitReached, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu 429 business code maps to usageLimitReached")
    }

    private static func testBusinessCodeWithoutSuccessFlagMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "code": "1310",
              "msg": "limit reached"
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.usageLimitReached, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu business code without success maps to usageLimitReached")
    }

    private static func testStringBusinessCodeMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: """
            {
              "code": "1309",
              "msg": "plan expired",
              "success": false
            }
            """.data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.planExpired, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu string business code maps to planExpired")
    }

    private static func testFetchSnapshotParsesTokenLimit(using harness: TestHarness) async {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_000_000)
        let resetAt = Date(timeIntervalSince1970: 1_715_018_000)
        let httpClient = ZhipuMockHTTPClient(response: HTTPResponse(
            data: quotaResponseData(percentage: 17, nextResetTime: Int(resetAt.timeIntervalSince1970 * 1000)),
            statusCode: 200
        ))
        let provider = ZhipuCodingPlanProvider(httpClient: httpClient, now: { fetchedAt })

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "test-zhipu-key")

            switch snapshot {
            case .planUsage(let usage):
                harness.expectEqual(usage.providerID, .zhipuCodingPlan, "zhipu provider id")
                harness.expectEqual(usage.windowLabel, "5h", "zhipu usage window")
                harness.expectEqual(usage.usagePercentage, Decimal(17), "zhipu usage percentage")
                harness.expectEqual(usage.resetAt, resetAt, "zhipu reset time")
                harness.expectTrue(usage.isAvailable, "zhipu usage available below limit")
                harness.expectEqual(usage.fetchedAt, fetchedAt, "zhipu fetched date")
            case .balance:
                harness.expectTrue(false, "zhipu snapshot should be plan usage")
            }

            harness.expectEqual(
                httpClient.lastRequest?.url,
                URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!,
                "zhipu quota request url"
            )
            harness.expectEqual(httpClient.lastRequest?.httpMethod, "GET", "zhipu quota request method")
            harness.expectEqual(
                httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-zhipu-key",
                "zhipu quota authorization header"
            )
        } catch {
            harness.expectTrue(false, "zhipu usage should not throw: \(error)")
        }
    }

    private static func testAuthenticationFailureMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401)))

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "bad-key")
        }, "zhipu 401 maps to authenticationFailed")
    }

    private static func testRateLimitMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429)))

        await harness.expectThrowsBalanceProviderError(.rateLimited, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu 429 maps to rateLimited")
    }

    private static func testUsageLimitBusinessCodeMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: errorResponseData(code: "1310", message: "limit reached"),
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.usageLimitReached, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu business usage limit maps to usageLimitReached")
    }

    private static func testPlanExpiredBusinessCodeMapsToProviderError(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: errorResponseData(code: "1309", message: "plan expired"),
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.planExpired, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu business plan expired maps to planExpired")
    }

    private static func testMalformedJSONMapsToDecodingFailure(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: "{".data(using: .utf8)!,
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.decodingFailed, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu malformed json maps to decodingFailed")
    }

    private static func testMissingTokenLimitMapsToMissingBalanceInfo(using harness: TestHarness) async {
        let provider = ZhipuCodingPlanProvider(httpClient: ZhipuMockHTTPClient(response: HTTPResponse(
            data: quotaResponseData(limitType: "TIME_LIMIT", percentage: 17, nextResetTime: nil),
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.missingBalanceInfo, {
            _ = try await provider.fetchSnapshot(apiKey: "test-key")
        }, "zhipu missing token limit maps to missingBalanceInfo")
    }

    private static func quotaResponseData(
        limitType: String = "TOKENS_LIMIT",
        percentage: Int,
        nextResetTime: Int?
    ) -> Data {
        let resetLine = nextResetTime.map { #","nextResetTime": \#($0)"# } ?? ""
        return """
        {
          "code": 200,
          "msg": "success",
          "success": true,
          "data": {
            "limits": [
              {
                "type": "\(limitType)",
                "usage": 10000000,
                "currentValue": 1700000,
                "percentage": \(percentage)\(resetLine)
              }
            ]
          }
        }
        """.data(using: .utf8)!
    }

    private static func errorResponseData(code: String, message: String) -> Data {
        """
        {
          "code": \(code),
          "msg": "\(message)",
          "success": false
        }
        """.data(using: .utf8)!
    }
}

private final class ZhipuMockHTTPClient: HTTPClient {
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
