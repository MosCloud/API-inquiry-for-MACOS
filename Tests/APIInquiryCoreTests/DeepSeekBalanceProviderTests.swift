import XCTest
@testable import APIInquiryCore

final class DeepSeekBalanceProviderTests: XCTestCase {
    func testFetchBalancePrefersCNY() async throws {
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

        let snapshot = try await provider.fetchBalance(apiKey: "test-key")

        XCTAssertEqual(snapshot.providerID, .deepseek)
        XCTAssertEqual(snapshot.currency, "CNY")
        XCTAssertEqual(snapshot.totalBalance, Decimal(string: "88.50", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(snapshot.grantedBalance, Decimal(string: "8.50", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(snapshot.toppedUpBalance, Decimal(string: "80.00", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(snapshot.isAvailable, true)
        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        XCTAssertEqual(httpClient.lastRequest?.url, URL(string: "https://api.deepseek.com/user/balance"))
        XCTAssertEqual(httpClient.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(httpClient.lastRequest?.httpMethod, "GET")
    }

    func testFetchBalanceFallsBackToFirstCurrencyWhenCNYIsMissing() async throws {
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

        let snapshot = try await provider.fetchBalance(apiKey: "test-key")

        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.totalBalance, Decimal(string: "1.23", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(snapshot.grantedBalance, Decimal(string: "0.23", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(snapshot.toppedUpBalance, Decimal(string: "1.00", locale: Locale(identifier: "en_US_POSIX")))
        XCTAssertEqual(snapshot.isAvailable, false)
    }

    func testAuthenticationFailureMapsToProviderError() async {
        let httpClient = MockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 401))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        await XCTAssertThrowsProviderError(.authenticationFailed) {
            try await provider.fetchBalance(apiKey: "test-key")
        }
    }

    func testRateLimitMapsToProviderError() async {
        let httpClient = MockHTTPClient(response: HTTPResponse(data: Data(), statusCode: 429))
        let provider = DeepSeekBalanceProvider(httpClient: httpClient)

        await XCTAssertThrowsProviderError(.rateLimited) {
            try await provider.fetchBalance(apiKey: "test-key")
        }
    }

    func testInvalidAmountMapsToProviderError() async {
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

        await XCTAssertThrowsProviderError(.invalidBalanceAmount("not-a-number")) {
            try await provider.fetchBalance(apiKey: "test-key")
        }
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

private func XCTAssertThrowsProviderError(
    _ expectedError: BalanceProviderError,
    operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected \(expectedError) to be thrown.", file: file, line: line)
    } catch let error as BalanceProviderError {
        XCTAssertEqual(error, expectedError, file: file, line: line)
    } catch {
        XCTFail("Expected \(expectedError), got \(error).", file: file, line: line)
    }
}
