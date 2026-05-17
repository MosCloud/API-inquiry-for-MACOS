import Foundation

public struct DeepSeekUsageExportParser {
    public init() {}

    public func parseExportArchive(
        _ csvFiles: [String: String],
        sourceFileName: String,
        importedAt: Date
    ) throws -> UsageDataset {
        let costEntry = Self.exportEntry(named: "cost", in: csvFiles)
        let amountEntry = Self.exportEntry(named: "amount", in: csvFiles)

        var missingEntries: [String] = []
        if costEntry == nil {
            missingEntries.append("cost")
        }
        if amountEntry == nil {
            missingEntries.append("amount")
        }
        guard missingEntries.isEmpty else {
            throw UsageImportError.missingRequiredArchiveEntries(missingEntries)
        }

        return try parse(
            costCSV: costEntry!.value,
            amountCSV: amountEntry!.value,
            sourceFileName: sourceFileName,
            importedAt: importedAt
        )
    }

    public func parse(
        costCSV: String,
        amountCSV: String,
        sourceFileName: String,
        importedAt: Date
    ) throws -> UsageDataset {
        let costTable = try UsageExportTable(csvText: costCSV)
        let amountTable = try UsageExportTable(csvText: amountCSV)
        try costTable.requireColumns(["utcdate", "model", "cost", "currency"])
        try amountTable.requireColumns(["utcdate", "model", "type", "amount"])

        let costSummaries = try parseCostSummaries(from: costTable)
        let amountSummaries = try parseAmountSummaries(from: amountTable)
        let keys = Set(costSummaries.keys).union(amountSummaries.keys)

        guard !keys.isEmpty else {
            throw UsageImportError.emptyFile
        }

        let records = keys.sorted().map { key in
            let costSummary = costSummaries[key] ?? UsageExportCostSummary()
            let amountSummary = amountSummaries[key] ?? UsageExportAmountSummary()

            return UsageRecord(
                occurredAt: key.occurredAt,
                model: key.model,
                requestCount: amountSummary.requestCount,
                inputTokens: amountSummary.inputTokens,
                outputTokens: amountSummary.outputTokens,
                totalTokens: amountSummary.inputTokens + amountSummary.outputTokens,
                cost: costSummary.cost,
                currency: Self.currencyLabel(for: costSummary.currencies)
            )
        }

        return UsageDataset(
            records: records,
            metadata: UsageImportMetadata(
                sourceFileName: sourceFileName,
                importedAt: importedAt,
                parserVersion: 2
            )
        )
    }

    private func parseCostSummaries(
        from table: UsageExportTable
    ) throws -> [UsageExportKey: UsageExportCostSummary] {
        var summaries: [UsageExportKey: UsageExportCostSummary] = [:]

        for row in table.dataRows {
            try table.validate(row)
            let key = try exportKey(from: row, table: table)
            let costText = table.value(for: "cost", in: row)
            guard let cost = Self.parseDecimal(costText) else {
                throw UsageImportError.invalidNumber(column: table.columnName(for: "cost"), value: costText)
            }

            let currency = table.value(for: "currency", in: row).uppercased()
            var summary = summaries[key] ?? UsageExportCostSummary()
            summary.cost += cost
            if !currency.isEmpty {
                summary.currencies.insert(currency)
            }
            summaries[key] = summary
        }

        return summaries
    }

    private func parseAmountSummaries(
        from table: UsageExportTable
    ) throws -> [UsageExportKey: UsageExportAmountSummary] {
        var summaries: [UsageExportKey: UsageExportAmountSummary] = [:]

        for row in table.dataRows {
            try table.validate(row)
            let key = try exportKey(from: row, table: table)
            let type = Self.normalizeHeader(table.value(for: "type", in: row))
            let amountText = table.value(for: "amount", in: row)
            guard let amount = Self.parseInt(amountText) else {
                throw UsageImportError.invalidNumber(column: table.columnName(for: "amount"), value: amountText)
            }

            var summary = summaries[key] ?? UsageExportAmountSummary()
            switch type {
            case "requestcount", "requests":
                summary.requestCount += amount
            case "inputtokens", "prompttokens", "inputcachehittokens", "inputcachemisstokens":
                summary.inputTokens += amount
            case "outputtokens", "completiontokens":
                summary.outputTokens += amount
            default:
                break
            }
            summaries[key] = summary
        }

        return summaries
    }

    private func exportKey(from row: [String], table: UsageExportTable) throws -> UsageExportKey {
        let dateText = table.value(for: "utcdate", in: row)
        guard let occurredAt = Self.parseDate(dateText) else {
            throw UsageImportError.invalidDate(column: table.columnName(for: "utcdate"), value: dateText)
        }

        let model = table.value(for: "model", in: row)
        guard !model.isEmpty else {
            throw UsageImportError.invalidCSV("A DeepSeek usage export row is missing the model value.")
        }

        return UsageExportKey(occurredAt: occurredAt, model: model)
    }

    private static func exportEntry(
        named expectedPrefix: String,
        in csvFiles: [String: String]
    ) -> (name: String, value: String)? {
        guard let entry = csvFiles.first(where: { name, _ in
            let baseName = name.split(separator: "/").last.map(String.init) ?? name
            let normalizedName = baseName.lowercased()
            return normalizedName.hasSuffix(".csv") && normalizedName.hasPrefix(expectedPrefix)
        }) else {
            return nil
        }

        return (name: entry.key, value: entry.value)
    }

    fileprivate static func normalizeHeader(_ header: String) -> String {
        header
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func parseDate(_ value: String) -> Date? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        for formatter in dateFormatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }

    private static func parseInt(_ value: String) -> Int? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        return Int(cleaned)
    }

    private static func parseDecimal(_ value: String) -> Decimal? {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func currencyLabel(for currencies: Set<String>) -> String {
        if currencies.isEmpty {
            return "--"
        }

        if currencies.count == 1, let currency = currencies.first {
            return currency
        }

        return "Mixed"
    }

    private static let dateFormatters: [DateFormatter] = [
        dateFormatter("yyyy-MM-dd"),
        dateFormatter("yyyy/MM/dd")
    ]

    private static func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

private struct UsageExportTable {
    let header: [String]
    let dataRows: [[String]]
    let columns: [String: Int]

    init(csvText: String) throws {
        let rows = try CSVTableParser.parseRows(csvText)
        guard let header = rows.first else {
            throw UsageImportError.emptyFile
        }

        self.header = header
        self.dataRows = Array(rows.dropFirst())
        var mappedColumns: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            let normalizedName = DeepSeekUsageExportParser.normalizeHeader(name)
            if mappedColumns[normalizedName] == nil {
                mappedColumns[normalizedName] = index
            }
        }
        self.columns = mappedColumns

        guard !dataRows.isEmpty else {
            throw UsageImportError.emptyFile
        }
    }

    func requireColumns(_ requiredColumns: [String]) throws {
        let missingColumns = requiredColumns.filter { columns[$0] == nil }
        guard missingColumns.isEmpty else {
            throw UsageImportError.missingRequiredColumns(missingColumns)
        }
    }

    func validate(_ row: [String]) throws {
        guard row.count == header.count else {
            throw UsageImportError.invalidCSV("A DeepSeek usage export row has \(row.count) fields, expected \(header.count).")
        }
    }

    func value(for normalizedColumn: String, in row: [String]) -> String {
        guard let index = columns[normalizedColumn], index < row.count else {
            return ""
        }

        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func columnName(for normalizedColumn: String) -> String {
        guard let index = columns[normalizedColumn], index < header.count else {
            return normalizedColumn
        }

        return header[index]
    }
}

private struct UsageExportKey: Hashable, Comparable {
    let occurredAt: Date
    let model: String

    static func < (lhs: UsageExportKey, rhs: UsageExportKey) -> Bool {
        if lhs.occurredAt == rhs.occurredAt {
            return lhs.model < rhs.model
        }

        return lhs.occurredAt < rhs.occurredAt
    }
}

private struct UsageExportCostSummary {
    var cost = Decimal(0)
    var currencies: Set<String> = []
}

private struct UsageExportAmountSummary {
    var requestCount = 0
    var inputTokens = 0
    var outputTokens = 0
}
