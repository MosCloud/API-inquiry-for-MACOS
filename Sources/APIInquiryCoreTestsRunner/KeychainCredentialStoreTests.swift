import APIInquiryCore
import Foundation

enum KeychainCredentialStoreTests {
    static func run(using harness: TestHarness) {
        testSaveAndLoadCredential(using: harness)
        testReplaceCredential(using: harness)
        testDeleteCredential(using: harness)
        testMissingCredentialReturnsNil(using: harness)
    }

    private static func testSaveAndLoadCredential(using harness: TestHarness) {
        let store = makeStore()
        let account = "deepseek-api-key"
        let key = "test-key-save-load"
        defer { try? store.deleteCredential(forAccount: account) }

        do {
            try store.saveCredential(key, forAccount: account)
            let loaded = try store.credential(forAccount: account)

            harness.expectEqual(loaded, key, "saved credential loads")
        } catch {
            harness.expectTrue(false, "save and load credential should not throw: \(error)")
        }
    }

    private static func testReplaceCredential(using harness: TestHarness) {
        let store = makeStore()
        let account = "deepseek-api-key"
        defer { try? store.deleteCredential(forAccount: account) }

        do {
            try store.saveCredential("test-key-first", forAccount: account)
            try store.saveCredential("test-key-second", forAccount: account)

            harness.expectEqual(try store.credential(forAccount: account), "test-key-second", "credential replacement")
        } catch {
            harness.expectTrue(false, "replace credential should not throw: \(error)")
        }
    }

    private static func testDeleteCredential(using harness: TestHarness) {
        let store = makeStore()
        let account = "deepseek-api-key"
        defer { try? store.deleteCredential(forAccount: account) }

        do {
            try store.saveCredential("test-key-delete", forAccount: account)
            try store.deleteCredential(forAccount: account)

            harness.expectEqual(try store.credential(forAccount: account), nil, "deleted credential is absent")
        } catch {
            harness.expectTrue(false, "delete credential should not throw: \(error)")
        }
    }

    private static func testMissingCredentialReturnsNil(using harness: TestHarness) {
        let store = makeStore()

        do {
            harness.expectEqual(try store.credential(forAccount: "missing-account"), nil, "missing credential")
        } catch {
            harness.expectTrue(false, "missing credential should not throw: \(error)")
        }
    }

    private static func makeStore() -> KeychainCredentialStore {
        KeychainCredentialStore(service: "com.api-inquiry.tests.\(UUID().uuidString)")
    }
}
