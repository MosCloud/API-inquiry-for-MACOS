import Combine
import Foundation

@MainActor
public final class BalanceRefreshController: ObservableObject {
    @Published public private(set) var state: BalanceState

    public let refreshInterval: TimeInterval

    private let provider: BalanceProvider
    private let credentialStore: CredentialStore
    private var autoRefreshTask: Task<Void, Never>?
    private var isRefreshing = false

    public init(
        provider: BalanceProvider,
        credentialStore: CredentialStore,
        initialState: BalanceState = .notConfigured,
        refreshInterval: TimeInterval = 300
    ) {
        self.provider = provider
        self.credentialStore = credentialStore
        self.state = initialState
        self.refreshInterval = refreshInterval
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    public func refresh() async {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let previousState = state

        do {
            guard let apiKey = try credentialStore.credential(forAccount: provider.credentialAccount),
                  !apiKey.isEmpty else {
                state = .notConfigured
                return
            }

            state = .loading(last: state.lastSnapshot)
            let snapshot = try await provider.fetchSnapshot(apiKey: apiKey)
            try Task.checkCancellation()
            state = .loaded(snapshot)
        } catch is CancellationError {
            state = previousState
        } catch let error as URLError where error.code == .cancelled {
            state = previousState
        } catch {
            state = .failed(
                message: Self.userMessage(for: error),
                kind: Self.failureKind(for: error),
                last: state.lastSnapshot
            )
        }
    }

    public func markNotConfigured() {
        state = .notConfigured
    }

    public func startAutoRefresh() {
        stopAutoRefresh()

        let interval = refreshInterval
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.nanoseconds(from: interval))
                } catch {
                    return
                }

                await self?.refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private static func userMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return "Refresh failed. Try again shortly."
    }

    private static func failureKind(for error: Error) -> BalanceFailureKind {
        if let providerError = error as? BalanceProviderError {
            return providerError.failureKind
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut:
                return .networkUnavailable
            default:
                return .unknown
            }
        }

        return .unknown
    }

    private static func nanoseconds(from interval: TimeInterval) -> UInt64 {
        UInt64(max(0, interval) * 1_000_000_000)
    }
}
