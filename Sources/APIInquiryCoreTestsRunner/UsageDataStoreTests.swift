import APIInquiryCore
import Foundation

enum UsageDataStoreTests {
    static func run(using harness: TestHarness) {
        testInMemoryStoreSavesLoadsAndClearsDataset(using: harness)
        testJSONStoreSavesLoadsAndClearsDataset(using: harness)
        testJSONStoreCreatesParentDirectory(using: harness)
    }

    private static func testInMemoryStoreSavesLoadsAndClearsDataset(using harness: TestHarness) {
        let store = InMemoryUsageDataStore()
        let dataset = makeDataset(sourceFileName: "memory.csv")

        harness.expectEqual(try? store.loadDataset(), nil, "empty in-memory usage store")
        try? store.saveDataset(dataset)
        harness.expectEqual(try? store.loadDataset(), dataset, "in-memory usage store load")
        try? store.clearDataset()
        harness.expectEqual(try? store.loadDataset(), nil, "in-memory usage store clear")
    }

    private static func testJSONStoreSavesLoadsAndClearsDataset(using harness: TestHarness) {
        let fileURL = temporaryStoreURL()
        let store = JSONUsageDataStore(fileURL: fileURL)
        let dataset = makeDataset(sourceFileName: "usage.csv")

        harness.expectEqual(try? store.loadDataset(), nil, "empty json usage store")
        try? store.saveDataset(dataset)
        harness.expectEqual(try? store.loadDataset(), dataset, "json usage store load")
        harness.expectTrue(FileManager.default.fileExists(atPath: fileURL.path), "json usage store file exists")
        try? store.clearDataset()
        harness.expectEqual(try? store.loadDataset(), nil, "json usage store clear")
        harness.expectTrue(!FileManager.default.fileExists(atPath: fileURL.path), "json usage store file removed")
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    private static func testJSONStoreCreatesParentDirectory(using harness: TestHarness) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("APIInquiryUsageStore-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Nested", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("usage-records.json")
        let store = JSONUsageDataStore(fileURL: fileURL)

        try? store.saveDataset(makeDataset(sourceFileName: "nested.csv"))

        harness.expectTrue(FileManager.default.fileExists(atPath: fileURL.path), "json usage store creates parent")
        try? FileManager.default.removeItem(at: directoryURL.deletingLastPathComponent())
    }

    private static func makeDataset(sourceFileName: String) -> UsageDataset {
        UsageDataset(
            records: [
                UsageRecord(
                    occurredAt: Date(timeIntervalSince1970: 1_716_000_000),
                    model: "deepseek-chat",
                    requestCount: 2,
                    inputTokens: 100,
                    outputTokens: 40,
                    totalTokens: 140,
                    cost: Decimal(string: "1.25", locale: Locale(identifier: "en_US_POSIX"))!,
                    currency: "CNY"
                )
            ],
            metadata: UsageImportMetadata(
                sourceFileName: sourceFileName,
                importedAt: Date(timeIntervalSince1970: 1_716_100_000),
                parserVersion: 1
            )
        )
    }

    private static func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("APIInquiryUsageStore-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("usage-records.json")
    }
}
