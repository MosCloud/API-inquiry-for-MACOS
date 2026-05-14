import Foundation

let harness = TestHarness()
TestHarnessTests.run(using: harness)
KeychainCredentialStoreTests.run(using: harness)
await DeepSeekBalanceProviderTests.run(using: harness)
harness.finish()
