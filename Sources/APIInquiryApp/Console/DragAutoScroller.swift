import AppKit
import SwiftUI

/// Scrolls the provider list while a card is being dragged near the top or bottom
/// of the visible area (#110).
///
/// SwiftUI has no drag auto-scroll, and `ScrollViewReader` can only jump to an
/// item, so this borrows the enclosing `NSScrollView` and scrolls it by a few
/// points per tick. The tick loop lives in the view; this type only answers
/// "how far should the content move right now".
@MainActor
final class DragAutoScroller {
    /// Pointer distance from the top/bottom edge that starts scrolling.
    static let triggerZone: CGFloat = 40
    /// Fraction of `triggerZone` travelled per second, so the scroll speeds up
    /// the closer the pointer gets to the edge.
    private static let pointsPerSecondAtEdge: CGFloat = 500

    private weak var scrollView: NSScrollView?

    func attach(_ scrollView: NSScrollView?) {
        self.scrollView = scrollView
    }

    var isAttached: Bool {
        scrollView != nil
    }

    /// Moves the content by the distance the pointer asks for and returns how far
    /// it actually moved (0 at the ends, or when the pointer is away from both
    /// edges). The caller feeds that delta back into its drag bookkeeping, because
    /// scrolling changes which card sits under a stationary pointer.
    func tick(deltaTime: TimeInterval) -> CGFloat {
        guard let scrollView,
              let documentView = scrollView.documentView,
              let window = scrollView.window else {
            return 0
        }

        let visible = window.convertToScreen(scrollView.convert(scrollView.bounds, to: nil))
        let pointer = NSEvent.mouseLocation
        guard visible.contains(CGPoint(x: visible.midX, y: pointer.y)) else {
            return 0
        }

        let distanceToBottom = pointer.y - visible.minY
        let distanceToTop = visible.maxY - pointer.y

        let direction: CGFloat
        let proximity: CGFloat
        if distanceToBottom < Self.triggerZone {
            direction = 1
            proximity = distanceToBottom
        } else if distanceToTop < Self.triggerZone {
            direction = -1
            proximity = distanceToTop
        } else {
            return 0
        }

        let strength = max(0, min(1, 1 - proximity / Self.triggerZone))
        let requested = direction * Self.pointsPerSecondAtEdge * strength * CGFloat(deltaTime)

        let clipView = scrollView.contentView
        let current = clipView.bounds.origin
        let maxOffset = max(0, documentView.bounds.height - clipView.bounds.height)
        let target = min(max(0, current.y + requested), maxOffset)
        let delta = target - current.y

        guard abs(delta) > 0.01 else {
            return 0
        }

        clipView.scroll(to: NSPoint(x: current.x, y: target))
        scrollView.reflectScrolledClipView(clipView)
        return delta
    }
}

/// Finds the `NSScrollView` that hosts the SwiftUI scroll content. Placed as a
/// zero-size background inside the list, so it resolves to the list's own scroll
/// view rather than whichever one is nearest the window.
struct ScrollViewResolver: NSViewRepresentable {
    let onChange: (NSScrollView?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { onChange(view.enclosingScrollView) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onChange(nsView.enclosingScrollView) }
    }
}
