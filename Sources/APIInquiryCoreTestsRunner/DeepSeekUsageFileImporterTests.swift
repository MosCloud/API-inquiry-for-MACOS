import APIInquiryCore
import Foundation

enum DeepSeekUsageFileImporterTests {
    static func run(using harness: TestHarness) {
        testImportsOfficialZipArchive(using: harness)
    }

    private static func testImportsOfficialZipArchive(using harness: TestHarness) {
        do {
            let exportDirectory = try makeOfficialExportDirectory()
            defer { try? FileManager.default.removeItem(at: exportDirectory) }

            let zipURL = try makeZipArchive(in: exportDirectory)
            let dataset = try DeepSeekUsageFileImporter().importUsageFile(
                at: zipURL,
                importedAt: DeepSeekUsageOfficialExportFixture.importedAt
            )

            harness.expectEqual(dataset.records.count, 4, "file importer official zip record count")
            harness.expectEqual(dataset.metadata.sourceFileName, DeepSeekUsageOfficialExportFixture.sourceFileName, "file importer source")
            harness.expectEqual(dataset.totals.cost, DeepSeekUsageOfficialExportFixture.decimal("3.6474440000000000"), "file importer official zip cost")
            harness.expectEqual(dataset.totals.totalTokens, 47_812_442, "file importer official zip total tokens")
        } catch {
            harness.expectTrue(false, "file importer official zip threw \(error)")
        }
    }

    private static func makeOfficialExportDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("api-inquiry-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try DeepSeekUsageOfficialExportFixture.costCSV.write(
            to: directory.appendingPathComponent("cost-2026-4.csv"),
            atomically: true,
            encoding: .utf8
        )
        try DeepSeekUsageOfficialExportFixture.amountCSV.write(
            to: directory.appendingPathComponent("amount-2026-4.csv"),
            atomically: true,
            encoding: .utf8
        )
        return directory
    }

    private static func makeZipArchive(in directory: URL) throws -> URL {
        let zipURL = directory.appendingPathComponent(DeepSeekUsageOfficialExportFixture.sourceFileName)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = [
            "-q",
            zipURL.lastPathComponent,
            "cost-2026-4.csv",
            "amount-2026-4.csv"
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UsageImportError.archiveReadFailed("zip exited with status \(process.terminationStatus).")
        }

        return zipURL
    }
}
