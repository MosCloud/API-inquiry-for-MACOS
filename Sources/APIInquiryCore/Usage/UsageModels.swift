import Foundation

public enum UsageImportError: Error, Equatable, LocalizedError {
    case emptyFile
    case missingRequiredColumns([String])
    case invalidDate(column: String, value: String)
    case invalidNumber(column: String, value: String)
    case invalidCSV(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file does not contain any importable usage records."
        case .missingRequiredColumns:
            return "The CSV is missing required usage columns."
        case .invalidDate(let column, _):
            return "The CSV date column '\(column)' could not be parsed."
        case .invalidNumber(let column, _):
            return "The CSV number column '\(column)' could not be parsed."
        case .invalidCSV:
            return "The CSV file could not be parsed."
        }
    }
}

public struct UsageRecord: Equatable, Codable {
    public let occurredAt: Date
    public let model: String
    public let requestCount: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let cost: Decimal
    public let currency: String

    public init(
        occurredAt: Date,
        model: String,
        requestCount: Int,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int,
        cost: Decimal,
        currency: String
    ) {
        self.occurredAt = occurredAt
        self.model = model
        self.requestCount = requestCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.cost = cost
        self.currency = currency.uppercased()
    }
}

public struct UsageImportMetadata: Equatable, Codable {
    public let sourceFileName: String
    public let importedAt: Date
    public let parserVersion: Int

    public init(sourceFileName: String, importedAt: Date, parserVersion: Int) {
        self.sourceFileName = sourceFileName
        self.importedAt = importedAt
        self.parserVersion = parserVersion
    }
}

public struct UsageTotals: Equatable, Codable {
    public let cost: Decimal
    public let currency: String
    public let requestCount: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int

    public init(
        cost: Decimal,
        currency: String,
        requestCount: Int,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int
    ) {
        self.cost = cost
        self.currency = currency
        self.requestCount = requestCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

public struct UsageModelSummary: Equatable, Codable {
    public let model: String
    public let cost: Decimal
    public let currency: String
    public let requestCount: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int

    public init(
        model: String,
        cost: Decimal,
        currency: String,
        requestCount: Int,
        inputTokens: Int,
        outputTokens: Int,
        totalTokens: Int
    ) {
        self.model = model
        self.cost = cost
        self.currency = currency
        self.requestCount = requestCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

public struct UsageImportSummary: Equatable, Codable {
    public let recordCount: Int
    public let totalCost: Decimal
    public let currency: String

    public init(recordCount: Int, totalCost: Decimal, currency: String) {
        self.recordCount = recordCount
        self.totalCost = totalCost
        self.currency = currency
    }
}

public struct UsageDataset: Equatable, Codable {
    public let records: [UsageRecord]
    public let metadata: UsageImportMetadata

    public init(records: [UsageRecord], metadata: UsageImportMetadata) {
        self.records = records
        self.metadata = metadata
    }

    public var totals: UsageTotals {
        UsageTotals(
            cost: records.reduce(Decimal(0)) { $0 + $1.cost },
            currency: currencyLabel(for: records.map(\.currency)),
            requestCount: records.reduce(0) { $0 + $1.requestCount },
            inputTokens: records.reduce(0) { $0 + $1.inputTokens },
            outputTokens: records.reduce(0) { $0 + $1.outputTokens },
            totalTokens: records.reduce(0) { $0 + $1.totalTokens }
        )
    }

    public var modelSummaries: [UsageModelSummary] {
        let grouped = Dictionary(grouping: records, by: \.model)

        return grouped.keys.sorted().map { model in
            let modelRecords = grouped[model] ?? []
            return UsageModelSummary(
                model: model,
                cost: modelRecords.reduce(Decimal(0)) { $0 + $1.cost },
                currency: currencyLabel(for: modelRecords.map(\.currency)),
                requestCount: modelRecords.reduce(0) { $0 + $1.requestCount },
                inputTokens: modelRecords.reduce(0) { $0 + $1.inputTokens },
                outputTokens: modelRecords.reduce(0) { $0 + $1.outputTokens },
                totalTokens: modelRecords.reduce(0) { $0 + $1.totalTokens }
            )
        }
    }

    public var dateRangeText: String {
        guard let firstDate = records.map(\.occurredAt).min(),
              let lastDate = records.map(\.occurredAt).max() else {
            return "--"
        }

        let firstText = Self.dateFormatter.string(from: firstDate)
        let lastText = Self.dateFormatter.string(from: lastDate)
        return firstText == lastText ? firstText : "\(firstText) - \(lastText)"
    }

    public var importSummary: UsageImportSummary {
        UsageImportSummary(
            recordCount: records.count,
            totalCost: totals.cost,
            currency: totals.currency
        )
    }

    private func currencyLabel(for currencies: [String]) -> String {
        let uniqueCurrencies = Set(currencies.map { $0.uppercased() })
        if uniqueCurrencies.isEmpty {
            return "--"
        }

        if uniqueCurrencies.count == 1, let currency = uniqueCurrencies.first {
            return currency
        }

        return "Mixed"
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
