import SwiftUI

enum RefreshActionFeedback: Hashable {
    case idle
    case refreshing
    case success
    case failure

    func systemImageName(default defaultName: String) -> String {
        switch self {
        case .idle, .refreshing:
            return defaultName
        case .success:
            return "checkmark"
        case .failure:
            return "xmark"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .idle, .refreshing:
            return .secondary
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    var disablesInteraction: Bool {
        self != .idle
    }

    var isCompletion: Bool {
        self == .success || self == .failure
    }
}

enum RefreshFeedbackTiming {
    static let turnDuration = 0.8
    static let turnDurationNanoseconds: UInt64 = 800_000_000
    static let completionDurationNanoseconds: UInt64 = 1_400_000_000
}

@MainActor
final class RefreshActionFeedbackController: ObservableObject {
    @Published private(set) var feedback: RefreshActionFeedback = .idle
    @Published private(set) var refreshTurn = 0

    private var refreshAnimationTask: Task<Void, Never>?
    private var refreshFeedbackResetTask: Task<Void, Never>?
    private var externalRefreshing = false
    private var reduceMotion = false

    func begin(reduceMotion: Bool) -> Bool {
        guard feedback == .idle else {
            return false
        }

        self.reduceMotion = reduceMotion
        refreshFeedbackResetTask?.cancel()
        refreshFeedbackResetTask = nil
        feedback = .refreshing
        updateAnimationLoop()
        return true
    }

    func complete(succeeded: Bool) {
        stopAnimationLoop()
        feedback = succeeded ? .success : .failure
        let targetFeedback = feedback

        refreshFeedbackResetTask?.cancel()
        refreshFeedbackResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: RefreshFeedbackTiming.completionDurationNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.feedback == targetFeedback else {
                    return
                }

                self.feedback = .idle
                self.refreshFeedbackResetTask = nil
                self.updateAnimationLoop()
            }
        }
    }

    func reset() {
        refreshFeedbackResetTask?.cancel()
        refreshFeedbackResetTask = nil
        feedback = .idle
        updateAnimationLoop()
    }

    func syncExternalRefreshing(_ isRefreshing: Bool, reduceMotion: Bool) {
        externalRefreshing = isRefreshing
        self.reduceMotion = reduceMotion
        updateAnimationLoop()
    }

    private var displayedFeedback: RefreshActionFeedback {
        if externalRefreshing && feedback == .idle {
            return .refreshing
        }

        return feedback
    }

    private var shouldAnimate: Bool {
        !reduceMotion && displayedFeedback == .refreshing
    }

    private func updateAnimationLoop() {
        if shouldAnimate {
            startAnimationLoop()
        } else {
            stopAnimationLoop()
        }
    }

    private func startAnimationLoop() {
        guard refreshAnimationTask == nil else {
            return
        }

        refreshTurn = 0
        refreshTurn += 1
        refreshAnimationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: RefreshFeedbackTiming.turnDurationNanoseconds)
                guard !Task.isCancelled else {
                    return
                }

                let shouldContinue = await MainActor.run {
                    guard let self else {
                        return false
                    }

                    guard self.shouldAnimate else {
                        self.refreshAnimationTask = nil
                        self.refreshTurn = 0
                        return false
                    }

                    self.refreshTurn += 1
                    return true
                }

                guard shouldContinue else {
                    return
                }
            }
        }
    }

    private func stopAnimationLoop() {
        refreshAnimationTask?.cancel()
        refreshAnimationTask = nil
        refreshTurn = 0
    }
}
