import Foundation

public struct DeepSeekUsageCSVParser {
    public init() {}

    public func parse(
        _ csvText: String,
        sourceFileName: String,
        importedAt: Date
    ) throws -> UsageDataset {
        let rows = try Self.parseCSVRows(csvText)
        guard !rows.isEmpty else {
            throw UsageImportError.emptyFile
        }

        let header = rows[0]
        let columns = Self.columns(from: header)
        let missingColumns = UsageColumn.requiredCanonicalNames.filter { columns[$0] == nil }
        guard missingColumns.isEmpty else {
            throw UsageImportError.missingRequiredColumns(missingColumns)
        }

        let records = try rows.dropFirst().enumerated().map { offset, row in
            try record(from: row, header: header, columns: columns, rowNumber: offset + 2)
        }

        guard !records.isEmpty else {
            throw UsageImportError.emptyFile
        }

        return UsageDataset(
            records: records,
            metadata: UsageImportMetadata(
                sourceFileName: sourceFileName,
                importedAt: importedAt,
                parserVersion: 1
            )
        )
    }

    private func record(
        from row: [String],
        header: [String],
        columns: [String: Int],
        rowNumber: Int
    ) throws -> UsageRecord {
        guard row.count == header.count else {
            throw UsageImportError.invalidCSV("Row \(rowNumber) has \(row.count) fields, expected \(header.count).")
        }

        let dateColumn = columnName(for: .date, header: header, columns: columns)
        let dateText = value(for: .date, row: row, columns: columns)
        guard let occurredAt = Self.parseDate(dateText) else {
            throw UsageImportError.invalidDate(column: dateColumn, value: dateText)
        }

        let requestColumn = columnName(for: .requests, header: header, columns: columns)
        let requestText = value(for: .requests, row: row, columns: columns)
        guard let requestCount = Self.parseInt(requestText) else {
            throw UsageImportError.invalidNumber(column: requestColumn, value: requestText)
        }

        let inputColumn = columnName(for: .inputTokens, header: header, columns: columns)
        let inputText = value(for: .inputTokens, row: row, columns: columns)
        guard let inputTokens = Self.parseInt(inputText) else {
            throw UsageImportError.invalidNumber(column: inputColumn, value: inputText)
        }

        let outputColumn = columnName(for: .outputTokens, header: header, columns: columns)
        let outputText = value(for: .outputTokens, row: row, columns: columns)
        guard let outputTokens = Self.parseInt(outputText) else {
            throw UsageImportError.invalidNumber(column: outputColumn, value: outputText)
        }

        let totalColumn = columnName(for: .totalTokens, header: header, columns: columns)
        let totalText = value(for: .totalTokens, row: row, columns: columns)
        guard let totalTokens = Self.parseInt(totalText) else {
            throw UsageImportError.invalidNumber(column: totalColumn, value: totalText)
        }

        let costColumn = columnName(for: .cost, header: header, columns: columns)
        let costText = value(for: .cost, row: row, columns: columns)
        guard let cost = Self.parseDecimal(costText) else {
            throw UsageImportError.invalidNumber(column: costColumn, value: costText)
        }

        return UsageRecord(
            occurredAt: occurredAt,
            model: value(for: .model, row: row, columns: columns),
            requestCount: requestCount,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            cost: cost,
            currency: value(for: .currency, row: row, columns: columns)
        )
    }

    private func value(for usageColumn: UsageColumn, row: [String], columns: [String: Int]) -> String {
        guard let index = columns[usageColumn.canonicalName], index < row.count else {
            return ""
        }

        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func columnName(
        for usageColumn: UsageColumn,
        header: [String],
        columns: [String: Int]
    ) -> String {
        guard let index = columns[usageColumn.canonicalName], index < header.count else {
            return usageColumn.canonicalName
        }

        return header[index]
    }

    private static func columns(from header: [String]) -> [String: Int] {
        var columns: [String: Int] = [:]

        for (index, name) in header.enumerated() {
            let normalizedName = normalizeHeader(name)
            guard let usageColumn = UsageColumn(alias: normalizedName) else {
                continue
            }

            columns[usageColumn.canonicalName] = index
        }

        return columns
    }

    private static func normalizeHeader(_ header: String) -> String {
        header
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func parseDate(_ value: String) -> Date? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        if let date = isoDateFormatter.date(from: text) {
            return date
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

    private static func parseCSVRows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInQuotes = false
        var index = text.startIndex

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            if !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if character == "\"" {
                if isInQuotes, nextIndex < text.endIndex, text[nextIndex] == "\"" {
                    field.append("\"")
                    index = text.index(after: nextIndex)
                    continue
                }

                isInQuotes.toggle()
                index = nextIndex
                continue
            }

            if character == ",", !isInQuotes {
                finishField()
                index = nextIndex
                continue
            }

            if (character == "\n" || character == "\r"), !isInQuotes {
                if character == "\r", nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = text.index(after: nextIndex)
                } else {
                    index = nextIndex
                }
                finishRow()
                continue
            }

            field.append(character)
            index = nextIndex
        }

        if isInQuotes {
            throw UsageImportError.invalidCSV("The CSV contains an unterminated quoted field.")
        }

        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return rows
    }

    private static let isoDateFormatter = ISO8601DateFormatter()

    private static let dateFormatters: [DateFormatter] = [
        dateFormatter("yyyy-MM-dd"),
        dateFormatter("yyyy/MM/dd"),
        dateFormatter("yyyy-MM-dd HH:mm:ss"),
        dateFormatter("yyyy/MM/dd HH:mm:ss")
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

private enum UsageColumn: CaseIterable {
    case date
    case model
    case requests
    case inputTokens
    case outputTokens
    case totalTokens
    case cost
    case currency

    var canonicalName: String {
        switch self {
        case .date:
            return "date"
        case .model:
            return "model"
        case .requests:
            return "requests"
        case .inputTokens:
            return "input_tokens"
        case .outputTokens:
            return "output_tokens"
        case .totalTokens:
            return "total_tokens"
        case .cost:
            return "cost"
        case .currency:
            return "currency"
        }
    }

    var aliases: Set<String> {
        switch self {
        case .date:
            return ["date", "time", "datetime", "timestamp", "createdat", "createdtime", "usagedate"]
        case .model:
            return ["model", "modelname"]
        case .requests:
            return ["requests", "request", "requestcount", "count"]
        case .inputTokens:
            return ["inputtokens", "prompttokens", "inputtoken", "prompttoken"]
        case .outputTokens:
            return ["outputtokens", "completiontokens", "outputtoken", "completiontoken"]
        case .totalTokens:
            return ["totaltokens", "tokens", "totaltoken"]
        case .cost:
            return ["cost", "amount", "usagecost", "totalcost", "fee"]
        case .currency:
            return ["currency", "currencycode"]
        }
    }

    static var requiredCanonicalNames: [String] {
        allCases.map(\.canonicalName)
    }

    init?(alias: String) {
        guard let column = Self.allCases.first(where: { $0.aliases.contains(alias) }) else {
            return nil
        }

        self = column
    }
}
