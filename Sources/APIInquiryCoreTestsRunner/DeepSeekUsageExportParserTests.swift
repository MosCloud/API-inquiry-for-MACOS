import APIInquiryCore
import Foundation

enum DeepSeekUsageExportParserTests {
    static func run(using harness: TestHarness) {
        testParsesOfficialCostAndAmountExports(using: harness)
        testMissingOfficialExportFileFails(using: harness)
    }

    private static func testParsesOfficialCostAndAmountExports(using harness: TestHarness) {
        let dataset = try? DeepSeekUsageExportParser().parse(
            costCSV: DeepSeekUsageOfficialExportFixture.costCSV,
            amountCSV: DeepSeekUsageOfficialExportFixture.amountCSV,
            sourceFileName: DeepSeekUsageOfficialExportFixture.sourceFileName,
            importedAt: DeepSeekUsageOfficialExportFixture.importedAt
        )

        harness.expectEqual(dataset?.records.count, 4, "official export record count")
        harness.expectEqual(dataset?.metadata.sourceFileName, DeepSeekUsageOfficialExportFixture.sourceFileName, "official export source")
        harness.expectEqual(dataset?.metadata.parserVersion, 2, "official export parser version")
        harness.expectEqual(dataset?.totals.cost, DeepSeekUsageOfficialExportFixture.decimal("3.6474440000000000"), "official export total cost")
        harness.expectEqual(dataset?.totals.currency, "CNY", "official export currency")
        harness.expectEqual(dataset?.totals.requestCount, 924, "official export request count")
        harness.expectEqual(dataset?.totals.inputTokens, 47_512_096, "official export input tokens")
        harness.expectEqual(dataset?.totals.outputTokens, 300_346, "official export output tokens")
        harness.expectEqual(dataset?.totals.totalTokens, 47_812_442, "official export total tokens")

        let april30 = dataset?.records.first { record in
            record.model == "deepseek-v4-flash" && Self.dateFormatter.string(from: record.occurredAt) == "2026-04-30"
        }
        harness.expectEqual(april30?.requestCount, 917, "official export grouped request count")
        harness.expectEqual(april30?.inputTokens, 47_420_294, "official export grouped input tokens")
        harness.expectEqual(april30?.outputTokens, 299_034, "official export grouped output tokens")
        harness.expectEqual(april30?.totalTokens, 47_719_328, "official export grouped total tokens")
        harness.expectEqual(april30?.cost, DeepSeekUsageOfficialExportFixture.decimal("3.5530180000000000"), "official export grouped cost")
    }

    private static func testMissingOfficialExportFileFails(using harness: TestHarness) {
        expectUsageImportError(
            .missingRequiredArchiveEntries(["amount"]),
            harness: harness,
            message: "official export missing amount csv"
        ) {
            _ = try DeepSeekUsageExportParser().parseExportArchive(
                ["cost-2026-4.csv": DeepSeekUsageOfficialExportFixture.costCSV],
                sourceFileName: DeepSeekUsageOfficialExportFixture.sourceFileName,
                importedAt: DeepSeekUsageOfficialExportFixture.importedAt
            )
        }
    }

    private static func expectUsageImportError(
        _ expected: UsageImportError,
        harness: TestHarness,
        message: String,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            harness.expectTrue(false, "\(message): expected \(expected), no error thrown")
        } catch let error as UsageImportError {
            harness.expectEqual(error, expected, message)
        } catch {
            harness.expectTrue(false, "\(message): expected \(expected), got \(error)")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}
