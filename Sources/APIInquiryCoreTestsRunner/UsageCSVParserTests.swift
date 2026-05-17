import APIInquiryCore
import Foundation

enum UsageCSVParserTests {
    static func run(using harness: TestHarness) {
        testParsesCSVWithoutDependingOnColumnOrder(using: harness)
        testParsesQuotedCommasAndEscapedQuotes(using: harness)
        testSkipsBlankRows(using: harness)
        testMissingRequiredColumnsFails(using: harness)
        testInvalidDateFails(using: harness)
        testInvalidNumberFails(using: harness)
        testEmptyCSVFails(using: harness)
    }

    private static func testParsesCSVWithoutDependingOnColumnOrder(using harness: TestHarness) {
        let csv = """
        Model,Cost,Date,Requests,Input Tokens,Output Tokens,Total Tokens,Currency
        deepseek-chat,1.25,2024-05-01,2,100,40,140,CNY
        deepseek-reasoner,2.75,2024-05-02,3,200,60,260,CNY
        """

        let dataset = try? DeepSeekUsageCSVParser().parse(
            csv,
            sourceFileName: "usage.csv",
            importedAt: importedAt
        )

        harness.expectEqual(dataset?.records.count, 2, "csv parser record count")
        harness.expectEqual(dataset?.records.first?.model, "deepseek-chat", "csv parser first model")
        harness.expectEqual(dataset?.records.first?.cost, decimal("1.25"), "csv parser first cost")
        harness.expectEqual(dataset?.totals.totalTokens, 400, "csv parser total tokens")
        harness.expectEqual(dataset?.metadata.sourceFileName, "usage.csv", "csv parser source file name")
    }

    private static func testParsesQuotedCommasAndEscapedQuotes(using harness: TestHarness) {
        let csv = """
        Date,Model,Requests,Input Tokens,Output Tokens,Total Tokens,Cost,Currency
        2024-05-01,"deepseek ""chat"", beta",1,10,4,14,0.50,CNY
        """

        let dataset = try? DeepSeekUsageCSVParser().parse(
            csv,
            sourceFileName: "quoted.csv",
            importedAt: importedAt
        )

        harness.expectEqual(dataset?.records.first?.model, "deepseek \"chat\", beta", "quoted csv model")
        harness.expectEqual(dataset?.records.first?.requestCount, 1, "quoted csv request count")
    }

    private static func testSkipsBlankRows(using harness: TestHarness) {
        let csv = """
        Date,Model,Requests,Input Tokens,Output Tokens,Total Tokens,Cost,Currency
        2024-05-01,deepseek-chat,1,10,4,14,0.50,CNY

        2024-05-02,deepseek-chat,2,20,6,26,0.75,CNY
        """

        let dataset = try? DeepSeekUsageCSVParser().parse(
            csv,
            sourceFileName: "blank-rows.csv",
            importedAt: importedAt
        )

        harness.expectEqual(dataset?.records.count, 2, "blank csv rows skipped")
    }

    private static func testMissingRequiredColumnsFails(using harness: TestHarness) {
        let csv = """
        Model,Requests,Input Tokens,Output Tokens,Total Tokens,Cost,Currency
        deepseek-chat,1,10,4,14,0.50,CNY
        """

        expectUsageImportError(
            .missingRequiredColumns(["date"]),
            harness: harness,
            message: "missing date column"
        ) {
            _ = try DeepSeekUsageCSVParser().parse(csv, sourceFileName: "missing.csv", importedAt: importedAt)
        }
    }

    private static func testInvalidDateFails(using harness: TestHarness) {
        let csv = """
        Date,Model,Requests,Input Tokens,Output Tokens,Total Tokens,Cost,Currency
        not-a-date,deepseek-chat,1,10,4,14,0.50,CNY
        """

        expectUsageImportError(
            .invalidDate(column: "Date", value: "not-a-date"),
            harness: harness,
            message: "invalid date"
        ) {
            _ = try DeepSeekUsageCSVParser().parse(csv, sourceFileName: "bad-date.csv", importedAt: importedAt)
        }
    }

    private static func testInvalidNumberFails(using harness: TestHarness) {
        let csv = """
        Date,Model,Requests,Input Tokens,Output Tokens,Total Tokens,Cost,Currency
        2024-05-01,deepseek-chat,one,10,4,14,0.50,CNY
        """

        expectUsageImportError(
            .invalidNumber(column: "Requests", value: "one"),
            harness: harness,
            message: "invalid request count"
        ) {
            _ = try DeepSeekUsageCSVParser().parse(csv, sourceFileName: "bad-number.csv", importedAt: importedAt)
        }
    }

    private static func testEmptyCSVFails(using harness: TestHarness) {
        expectUsageImportError(.emptyFile, harness: harness, message: "empty csv") {
            _ = try DeepSeekUsageCSVParser().parse("", sourceFileName: "empty.csv", importedAt: importedAt)
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

    private static let importedAt = Date(timeIntervalSince1970: 1_716_000_000)

    private static func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
