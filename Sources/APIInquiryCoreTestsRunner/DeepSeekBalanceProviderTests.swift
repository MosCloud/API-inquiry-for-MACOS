import APIInquiryCore
import Foundation

enum DeepSeekBalanceProviderTests {
    static func run(using harness: TestHarness) async {
        await testFetchBalancePrefersCNY(using: harness)
        await testFetchSnapshotWrapsBalance(using: harness)
        await testFetchBalanceFallsBackToFirstCurrencyWhenCNYIsMissing(using: harness)
        await testAuthenticationFailureMapsToProviderError(using: harness)
        await testRateLimitMapsToProviderError(using: harness)
        await testInvalidAmountMapsToProviderError(using: harness)
        await testInvalidAmountRejectsTrailingCharacters(using: harness)
        await testInvalidAmountRejectsGroupingSeparators(using: harness)
    }

    private static func testFetchSnapshotWrapsBalance(using harness: TestHarness) async {
        let httpClient = MockHTTPClient(response: HTTPResponse(
            data: responseData(totalBalance: "68.65"),
            statusCode: 200
        ))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        do {
            let snapshot = try await provider.fetchSnapshot(apiKey: "test-key")

            switch snapshot {
            case .balance(let balance):
                harness.expectEqual(balance.providerID, .deepseek, "deepseek snapshot provider id")
                harness.expectEqual(balance.totalBalance, decimal("68.65"), "deepseek snapshot balance")
            case .planUsage:
                harness.expectTrue(false, "deepseek snapshot should be a balance")
            case .quotaUsage:
                harness.expectTrue(false, "deepseek snapshot should be a balance")
            }
        } catch {
            harness.expectTrue(false, "deepseek snapshot should not throw: \(error)")
        }
    }

    private static func testFetchBalancePrefersCNY(using harness: TestHarness) async {
        let fetchedAt = Date(timeIntervalSince1970: 1_715_000_000)
        let httpClient = MockHTTPClient(response: HTTPResponse(
            data: """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "USD",
                  "total_balance": "1.23",
                  "granted_balance": "0.23",
                  "topped_up_balance": "1.00"
                },
                {
                  "currency": "CNY",
                  "total_balance": "88.50",
                  "granted_balance": "8.50",
                  "topped_up_balance": "80.00"
                }
              ]
            }
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient, now: { fetchedAt })

        do {
            let snapshot = try await provider.fetchBalance(apiKey: "test-key")

            harness.expectEqual(snapshot.providerID, .deepseek, "prefers CNY provider ID")
            harness.expectEqual(snapshot.currency, "CNY", "prefers CNY currency")
            harness.expectEqual(snapshot.totalBalance, decimal("88.50"), "prefers CNY total balance")
            harness.expectEqual(snapshot.grantedBalance, decimal("8.50"), "prefers CNY granted balance")
            harness.expectEqual(snapshot.toppedUpBalance, decimal("80.00"), "prefers CNY topped-up balance")
            harness.expectTrue(snapshot.isAvailable, "prefers CNY availability")
            harness.expectEqual(snapshot.fetchedAt, fetchedAt, "prefers CNY fetched date")
            harness.expectEqual(httpClient.lastRequest?.url, URL(string: "https://api.deepseek.com/user/balance"), "prefers CNY request URL")
            harness.expectEqual(httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key", "prefers CNY authorization header")
            harness.expectEqual(httpClient.lastRequest?.httpMethod, "GET", "prefers CNY request method")
        } catch {
            harness.expectTrue(false, "prefers CNY should not throw: \(error)")
        }
    }

    private static func testFetchBalanceFallsBackToFirstCurrencyWhenCNYIsMissing(using harness: TestHarness) async {
        let httpClient = MockHTTPClient(response: HTTPResponse(
            data: """
            {
              "is_available": false,
              "balance_infos": [
                {
                  "currency": "USD",
                  "total_balance": "1.23",
                  "granted_balance": "0.23",
                  "topped_up_balance": "1.00"
                }
              ]
            }
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        do {
            let snapshot = try await provider.fetchBalance(apiKey: "test-key")

            harness.expectEqual(snapshot.currency, "USD", "fallback currency")
            harness.expectEqual(snapshot.totalBalance, decimal("1.23"), "fallback total balance")
            harness.expectEqual(snapshot.grantedBalance, decimal("0.23"), "fallback granted balance")
            harness.expectEqual(snapshot.toppedUpBalance, decimal("1.00"), "fallback topped-up balance")
            harness.expectTrue(!snapshot.isAvailable, "fallback availability")
        } catch {
            harness.expectTrue(false, "fallback currency should not throw: \(error)")
        }
    }

    private static func testAuthenticationFailureMapsToProviderError(using harness: TestHarness) async {
        let httpClient = MockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        await harness.expectThrowsBalanceProviderError(.authenticationFailed, {
            _ = try await provider.fetchBalance(apiKey: "test-key")
        }, "401 maps to authenticationFailed")
    }

    private static func testRateLimitMapsToProviderError(using harness: TestHarness) async {
        let httpClient = MockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        await harness.expectThrowsBalanceProviderError(.rateLimited, {
            _ = try await provider.fetchBalance(apiKey: "test-key")
        }, "429 maps to rateLimited")
    }

    private static func testInvalidAmountMapsToProviderError(using harness: TestHarness) async {
        let httpClient = MockHTTPClient(response: HTTPResponse(
            data: """
            {
              "is_available": true,
              "balance_infos": [
                {
                  "currency": "CNY",
                  "total_balance": "not-a-number",
                  "granted_balance": "0.23",
                  "topped_up_balance": "1.00"
                }
              ]
            }
            """.data(using: .utf8)!,
            statusCode: 200
        ))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        await harness.expectThrowsBalanceProviderError(.invalidBalanceAmount("not-a-number"), {
            _ = try await provider.fetchBalance(apiKey: "test-key")
        }, "invalid total_balance maps to invalidBalanceAmount")
    }

    private static func testInvalidAmountRejectsTrailingCharacters(using harness: TestHarness) async {
        let provider = DeepSeekBalanceProvider(httpClient: MockHTTPClient(response: HTTPResponse(
            data: responseData(totalBalance: "1.23abc"),
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.invalidBalanceAmount("1.23abc"), {
            _ = try await provider.fetchBalance(apiKey: "test-key")
        }, "trailing characters map to invalidBalanceAmount")
    }

    private static func testInvalidAmountRejectsGroupingSeparators(using harness: TestHarness) async {
        let provider = DeepSeekBalanceProvider(httpClient: MockHTTPClient(response: HTTPResponse(
            data: responseData(totalBalance: "1,234.56"),
            statusCode: 200
        )))

        await harness.expectThrowsBalanceProviderError(.invalidBalanceAmount("1,234.56"), {
            _ = try await provider.fetchBalance(apiKey: "test-key")
        }, "grouping separators map to invalidBalanceAmount")
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private static func responseData(totalBalance: String) -> Data {
        """
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "CNY",
              "total_balance": "\(totalBalance)",
              "granted_balance": "0.23",
              "topped_up_balance": "1.00"
            }
          ]
        }
        """.data(using: .utf8)!
    }
}

private final class MockHTTPClient: HTTPClient {
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
