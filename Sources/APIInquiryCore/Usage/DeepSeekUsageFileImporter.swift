import Foundation

public protocol UsageFileImporting {
    func importUsageFile(at url: URL, importedAt: Date) throws -> UsageDataset
}

public protocol UsageArchiveReading {
    func csvFiles(in archiveURL: URL) throws -> [String: String]
}

public struct DeepSeekUsageFileImporter: UsageFileImporting {
    private let csvParser: DeepSeekUsageCSVParser
    private let exportParser: DeepSeekUsageExportParser
    private let archiveReader: UsageArchiveReading

    public init(
        csvParser: DeepSeekUsageCSVParser = DeepSeekUsageCSVParser(),
        exportParser: DeepSeekUsageExportParser = DeepSeekUsageExportParser(),
        archiveReader: UsageArchiveReading = SystemUsageArchiveReader()
    ) {
        self.csvParser = csvParser
        self.exportParser = exportParser
        self.archiveReader = archiveReader
    }

    public func importUsageFile(at url: URL, importedAt: Date) throws -> UsageDataset {
        switch url.pathExtension.lowercased() {
        case "zip":
            let csvFiles = try archiveReader.csvFiles(in: url)
            return try exportParser.parseExportArchive(
                csvFiles,
                sourceFileName: url.lastPathComponent,
                importedAt: importedAt
            )

        case "csv", "txt":
            let csvText = try String(contentsOf: url, encoding: .utf8)
            return try csvParser.parse(
                csvText,
                sourceFileName: url.lastPathComponent,
                importedAt: importedAt
            )

        default:
            throw UsageImportError.unsupportedFileType(url.pathExtension)
        }
    }
}

public struct SystemUsageArchiveReader: UsageArchiveReading {
    public init() {}

    public func csvFiles(in archiveURL: URL) throws -> [String: String] {
        let entryNames = try runUnzip(arguments: ["-Z1", archiveURL.path])
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.lowercased().hasSuffix(".csv") }

        guard !entryNames.isEmpty else {
            throw UsageImportError.missingRequiredArchiveEntries(["cost", "amount"])
        }

        var csvFiles: [String: String] = [:]
        for entryName in entryNames {
            csvFiles[entryName] = try runUnzip(arguments: ["-p", archiveURL.path, entryName])
        }

        return csvFiles
    }

    private func runUnzip(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments

        let output = Pipe()
        let errorOutput = Pipe()
        process.standardOutput = output
        process.standardError = errorOutput

        do {
            try process.run()
        } catch {
            throw UsageImportError.archiveReadFailed(error.localizedDescription)
        }

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "unzip exited with status \(process.terminationStatus)."
            throw UsageImportError.archiveReadFailed(message)
        }

        guard let text = String(data: outputData, encoding: .utf8) else {
            throw UsageImportError.archiveReadFailed("Archive CSV content is not valid UTF-8.")
        }

        return text
    }
}
