import APIInquiryCore
import Foundation

enum CodexCredentialParserTests {
    static func run(using harness: TestHarness) {
        testRawTokenParsing(using: harness)
        testBearerTokenNormalization(using: harness)
        testAuthJSONParsing(using: harness)
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
}
