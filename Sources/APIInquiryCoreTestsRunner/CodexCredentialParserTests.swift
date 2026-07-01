import APIInquiryCore
import Foundation

enum CodexCredentialParserTests {
    static func run(using harness: TestHarness) {
        testRawTokenParsing(using: harness)
        testBearerTokenNormalization(using: harness)
        testAuthJSONParsing(using: harness)
        testAuthJSONAccessTokenAliases(using: harness)
        testAuthJSONBearerAccessTokenNormalization(using: harness)
        testAuthJSONBearerAccessTokenRejectsEmptyValue(using: harness)
        testAuthJSONAccountIDAliases(using: harness)
    }

    private static func testRawTokenParsing(using harness: TestHarness) {
        do {
            let raw = try CodexCredentialParser.parse("test-token")
            harness.expectEqual(raw.accessToken, "test-token", "raw token parsed")
            harness.expectEqual(raw.accountID, nil, "raw token has no account id")
        } catch {
            harness.expectTrue(false, "raw token parse should not throw: \(error)")
        }
    }

    private static func testBearerTokenNormalization(using harness: TestHarness) {
        do {
            let bearer = try CodexCredentialParser.parse("Bearer bearer-token")
            harness.expectEqual(bearer.accessToken, "bearer-token", "bearer token normalized")
            harness.expectEqual(bearer.accountID, nil, "bearer token has no account id")
        } catch {
            harness.expectTrue(false, "bearer token parse should not throw: \(error)")
        }
    }

    private static func testAuthJSONParsing(using harness: TestHarness) {
        do {
            let json = try CodexCredentialParser.parse(
                """
                {
                  "tokens": {
                    "access_token": "json-token",
                    "account_id": "account-123"
                  }
                }
                """
            )
            harness.expectEqual(json.accessToken, "json-token", "auth json token parsed")
            harness.expectEqual(json.accountID, "account-123", "auth json account parsed")
        } catch {
            harness.expectTrue(false, "auth json parse should not throw: \(error)")
        }
    }

    private static func testAuthJSONAccessTokenAliases(using harness: TestHarness) {
        let cases: [(name: String, json: String, expected: String)] = [
            (
                "tokens.access_token",
                """
                {
                  "tokens": {
                    "access_token": "json-token"
                  }
                }
                """,
                "json-token"
            ),
            (
                "top-level accessToken",
                """
                {
                  "accessToken": "json-token"
                }
                """,
                "json-token"
            ),
            (
                "top-level access_token",
                """
                {
                  "access_token": "json-token"
                }
                """,
                "json-token"
            )
        ]

        for testCase in cases {
            do {
                let credential = try CodexCredentialParser.parse(testCase.json)
                harness.expectEqual(credential.accessToken, testCase.expected, "\(testCase.name) parsed")
            } catch {
                harness.expectTrue(false, "\(testCase.name) parse should not throw: \(error)")
            }
        }
    }

    private static func testAuthJSONBearerAccessTokenNormalization(using harness: TestHarness) {
        do {
            let credential = try CodexCredentialParser.parse(
                """
                {
                  "tokens": {
                    "access_token": "Bearer json-token"
                  }
                }
                """
            )
            harness.expectEqual(credential.accessToken, "json-token", "auth json bearer token normalized")
        } catch {
            harness.expectTrue(false, "auth json bearer token parse should not throw: \(error)")
        }
    }

    private static func testAuthJSONBearerAccessTokenRejectsEmptyValue(using harness: TestHarness) {
        do {
            _ = try CodexCredentialParser.parse(
                """
                {
                  "tokens": {
                    "access_token": "Bearer   "
                  }
                }
                """
            )
            harness.expectTrue(false, "empty bearer token should fail")
        } catch BalanceProviderError.authenticationFailed {
            harness.expectTrue(true, "empty bearer token fails authentication")
        } catch {
            harness.expectTrue(false, "empty bearer token should fail with authenticationFailed: \(error)")
        }
    }

    private static func testAuthJSONAccountIDAliases(using harness: TestHarness) {
        let cases: [(name: String, json: String, expected: String)] = [
            (
                "tokens.account_id",
                """
                {
                  "tokens": {
                    "access_token": "json-token",
                    "account_id": "account-123"
                  }
                }
                """,
                "account-123"
            ),
            (
                "top-level account_id",
                """
                {
                  "access_token": "json-token",
                  "account_id": "account-123"
                }
                """,
                "account-123"
            ),
            (
                "top-level accountID",
                """
                {
                  "access_token": "json-token",
                  "accountID": "account-123"
                }
                """,
                "account-123"
            )
        ]

        for testCase in cases {
            do {
                let credential = try CodexCredentialParser.parse(testCase.json)
                harness.expectEqual(credential.accountID, testCase.expected, "\(testCase.name) parsed")
            } catch {
                harness.expectTrue(false, "\(testCase.name) parse should not throw: \(error)")
            }
        }
    }
}
