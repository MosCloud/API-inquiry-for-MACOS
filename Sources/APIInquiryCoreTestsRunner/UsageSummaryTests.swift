import APIInquiryCore
import Foundation

enum UsageSummaryTests {
    static func run(using harness: TestHarness) {
        testTotalsAggregateUsageRecords(using: harness)
        testModelSummariesGroupAndSortByModel(using: harness)
        testMixedCurrencyTotalsDoNotConvertAmounts(using: harness)
        testEmptyDatasetUsesZeroTotals(using: harness)
    }

    private static func testTotalsAggregateUsageRecords(using harness: TestHarness) {
        let dataset = UsageDataset(
            records: [
                makeUsageRecord(day: 1, model: "deepseek-chat", requests: 2, input: 100, output: 40, total: 140, cost: "1.25"),
                makeUsageRecord(day: 2, model: "deepseek-reasoner", requests: 3, input: 200, output: 60, total: 260, cost: "2.75")
            ],
            metadata: makeMetadata()
        )

        harness.expectEqual(dataset.totals.cost, decimal("4.00"), "usage total cost")
        harness.expectEqual(dataset.totals.currency, "CNY", "usage total currency")
        harness.expectEqual(dataset.totals.requestCount, 5, "usage total requests")
        harness.expectEqual(dataset.totals.inputTokens, 300, "usage total input tokens")
        harness.expectEqual(dataset.totals.outputTokens, 100, "usage total output tokens")
        harness.expectEqual(dataset.totals.totalTokens, 400, "usage total tokens")
        harness.expectEqual(dataset.dateRangeText, "2024-05-01 - 2024-05-02", "usage date range")
        harness.expectEqual(dataset.importSummary.recordCount, 2, "usage import summary count")
        harness.expectEqual(dataset.importSummary.totalCost, decimal("4.00"), "usage import summary cost")
    }

    private static func testModelSummariesGroupAndSortByModel(using harness: TestHarness) {
        let dataset = UsageDataset(
            records: [
                makeUsageRecord(day: 1, model: "deepseek-reasoner", requests: 3, input: 300, output: 120, total: 420, cost: "3.50"),
                makeUsageRecord(day: 1, model: "deepseek-chat", requests: 1, input: 50, output: 20, total: 70, cost: "0.50"),
                makeUsageRecord(day: 2, model: "deepseek-chat", requests: 2, input: 70, output: 30, total: 100, cost: "0.75")
            ],
            metadata: makeMetadata()
        )

        harness.expectEqual(
            dataset.modelSummaries,
            [
                UsageModelSummary(
                    model: "deepseek-chat",
                    cost: decimal("1.25"),
                    currency: "CNY",
                    requestCount: 3,
                    inputTokens: 120,
                    outputTokens: 50,
                    totalTokens: 170
                ),
                UsageModelSummary(
                    model: "deepseek-reasoner",
                    cost: decimal("3.50"),
                    currency: "CNY",
                    requestCount: 3,
                    inputTokens: 300,
                    outputTokens: 120,
                    totalTokens: 420
                )
            ],
            "usage model summaries"
        )
    }

    private static func testMixedCurrencyTotalsDoNotConvertAmounts(using harness: TestHarness) {
        let dataset = UsageDataset(
            records: [
                makeUsageRecord(day: 1, model: "deepseek-chat", requests: 1, input: 10, output: 4, total: 14, cost: "1.00", currency: "CNY"),
                makeUsageRecord(day: 2, model: "deepseek-chat", requests: 1, input: 20, output: 6, total: 26, cost: "2.00", currency: "USD")
            ],
            metadata: makeMetadata()
        )

        harness.expectEqual(dataset.totals.cost, decimal("3.00"), "mixed currency keeps numeric sum")
        harness.expectEqual(dataset.totals.currency, "Mixed", "mixed currency label")
        harness.expectEqual(dataset.modelSummaries.first?.currency, "Mixed", "mixed model currency label")
    }

    private static func testEmptyDatasetUsesZeroTotals(using harness: TestHarness) {
        let dataset = UsageDataset(records: [], metadata: makeMetadata())

        harness.expectEqual(dataset.totals.cost, decimal("0"), "empty usage total cost")
        harness.expectEqual(dataset.totals.currency, "--", "empty usage total currency")
        harness.expectEqual(dataset.totals.requestCount, 0, "empty usage total requests")
        harness.expectEqual(dataset.dateRangeText, "--", "empty usage date range")
        harness.expectEqual(dataset.modelSummaries, [], "empty usage model summaries")
    }

    private static func makeUsageRecord(
        day: Int,
        model: String,
        requests: Int,
        input: Int,
        output: Int,
        total: Int,
        cost: String,
        currency: String = "CNY"
    ) -> UsageRecord {
        UsageRecord(
            occurredAt: date(day: day),
            model: model,
            requestCount: requests,
            inputTokens: input,
            outputTokens: output,
            totalTokens: total,
            cost: decimal(cost),
            currency: currency
        )
    }

    private static func makeMetadata() -> UsageImportMetadata {
        UsageImportMetadata(
            sourceFileName: "usage.csv",
            importedAt: date(day: 3),
            parserVersion: 1
        )
    }

    private static func date(day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2024
        components.month = 5
        components.day = day
        return components.date!
    }

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
