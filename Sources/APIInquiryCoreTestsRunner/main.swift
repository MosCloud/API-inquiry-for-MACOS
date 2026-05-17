import Foundation

let harness = TestHarness()
TestHarnessTests.run(using: harness)
KeychainCredentialStoreTests.run(using: harness)
AutoStartModelsTests.run(using: harness)
LastRefreshTimeFormatterTests.run(using: harness)
UsageSummaryTests.run(using: harness)
UsageCSVParserTests.run(using: harness)
await BalanceRefreshControllerTests.run(using: harness)
await MenuBarBalanceViewModelTests.run(using: harness)
await DeepSeekBalanceProviderTests.run(using: harness)
harness.finish()
