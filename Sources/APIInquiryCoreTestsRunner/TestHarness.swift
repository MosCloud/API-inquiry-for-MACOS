import APIInquiryCore
import Darwin
import Foundation

enum TestHarnessResult: Equatable {
    case passed(expectationCount: Int)
    case failed(expectationCount: Int, failures: [String])
}

final class TestHarness {
    private var expectationCount = 0
    private var failures: [String] = []

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        expectationCount += 1
        guard actual == expected else {
            failures.append("\(message): expected \(expected), got \(actual)")
            return
        }
    }

    func expectTrue(_ condition: Bool, _ message: String) {
        expectationCount += 1
        guard condition else {
            failures.append(message)
            return
        }
    }

    func expectThrowsBalanceProviderError(
        _ expected: BalanceProviderError,
        _ operation: () async throws -> Void,
        _ message: String
    ) async {
        expectationCount += 1
        do {
            try await operation()
            failures.append("\(message): expected \(expected), but no error was thrown")
        } catch let error as BalanceProviderError {
            guard error == expected else {
                failures.append("\(message): expected \(expected), got \(error)")
                return
            }
        } catch {
            failures.append("\(message): expected \(expected), got \(error)")
        }
    }

    var result: TestHarnessResult {
        if expectationCount == 0 && failures.isEmpty {
            return .failed(expectationCount: 0, failures: ["No expectations were run."])
        }

        if failures.isEmpty {
            return .passed(expectationCount: expectationCount)
        }

        return .failed(expectationCount: expectationCount, failures: failures)
    }

    func finish() -> Never {
        switch result {
        case .passed(let expectationCount):
            print("PASS: \(expectationCount) expectations")
            exit(0)

        case .failed(let expectationCount, let failures):
            print("FAIL: \(failures.count) failure(s) across \(expectationCount) expectations")
            for failure in failures {
                print("- \(failure)")
            }
            exit(1)
        }
    }
}
