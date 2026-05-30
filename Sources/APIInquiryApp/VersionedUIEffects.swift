import APIInquiryCore
import SwiftUI

extension View {
    @ViewBuilder
    func apiInquiryNumericTextTransition(value: Double?, reduceMotion: Bool = false) -> some View {
        if reduceMotion {
            self
        } else if #available(macOS 14.0, *), let value {
            contentTransition(.numericText(value: value))
        } else {
            contentTransition(.numericText(countsDown: false))
        }
    }

    @ViewBuilder
    func apiInquiryTopChangeTransition(reduceMotion: Bool) -> some View {
        if reduceMotion {
            transition(.opacity)
        } else {
            transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    func apiInquirySubtleAnimation<Value: Equatable>(value: Value, reduceMotion: Bool) -> some View {
        animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: value)
    }

    @ViewBuilder
    func apiInquiryRefreshTurnEffect(turn: Int, duration: Double, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            rotationEffect(.degrees(Double(turn) * 360))
                .animation(.linear(duration: duration), value: turn)
        }
    }

    @ViewBuilder
    func apiInquirySettingsFeedback(_ feedback: SettingsFeedback?) -> some View {
        if #available(macOS 14.0, *) {
            sensoryFeedback(trigger: feedback) { _, newFeedback in
                newFeedback?.kind.apiInquirySensoryFeedback
            }
        } else {
            self
        }
    }
}

@available(macOS 14.0, *)
private extension SettingsFeedbackKind {
    var apiInquirySensoryFeedback: SensoryFeedback {
        switch self {
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}
