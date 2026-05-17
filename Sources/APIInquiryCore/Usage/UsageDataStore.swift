import Foundation

public protocol UsageDataStore {
    func loadDataset() throws -> UsageDataset?
    func saveDataset(_ dataset: UsageDataset) throws
    func clearDataset() throws
}

public final class InMemoryUsageDataStore: UsageDataStore {
    private var dataset: UsageDataset?

    public init(dataset: UsageDataset? = nil) {
        self.dataset = dataset
    }

    public func loadDataset() throws -> UsageDataset? {
        dataset
    }

    public func saveDataset(_ dataset: UsageDataset) throws {
        self.dataset = dataset
    }

    public func clearDataset() throws {
        dataset = nil
    }
}

public final class JSONUsageDataStore: UsageDataStore {
    public let fileURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL = JSONUsageDataStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadDataset() throws -> UsageDataset? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(UsageDataset.self, from: data)
    }

    public func saveDataset(_ dataset: UsageDataset) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(dataset)
        try data.write(to: fileURL, options: .atomic)
    }

    public func clearDataset() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    public static func defaultFileURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("API Inquiry", isDirectory: true)
            .appendingPathComponent("usage-records.json")
    }
}
