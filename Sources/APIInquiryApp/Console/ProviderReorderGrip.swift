import APIInquiryCore
import AppKit
import SwiftUI

/// The six-dot drag handle that sits in the dead strip at the bottom-right of a
/// provider card (#110).
///
/// It lives inside the card rather than in the gap between cards so the card stays
/// one visual object, and it is deliberately faint: reordering is rare, and the
/// handle should not compete with the provider's numbers.
struct ProviderReorderGrip: View {
    let strings: LocalizedStrings
    let isActive: Bool

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 2.5) {
                    dot
                    dot
                }
            }
        }
        .frame(width: 18, height: 20)
        .contentShape(Rectangle())
        .opacity(isActive ? 0.85 : (isHovering ? 0.8 : 0.4))
        .onHover { hovering in
            isHovering = hovering
            // A drag handle that does not react to the pointer is a button that
            // turns out not to be one; set() is used instead of push()/pop() so a
            // missed exit event cannot leave the arrow cursor stuck.
            if hovering {
                NSCursor.openHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(strings.reorderProviders)
        .accessibilityLabel(strings.reorderProviders)
    }

    private var dot: some View {
        Circle()
            .fill(Color.secondary)
            .frame(width: 2.5, height: 2.5)
    }
}
