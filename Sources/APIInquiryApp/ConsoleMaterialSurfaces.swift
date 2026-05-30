import AppKit
import SwiftUI

struct MenuBarGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var accessibilityDisplayShouldIncreaseContrast =
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    var body: some View {
        APIInquiryGlassSurface(
            cornerRadius: 22,
            solidColor: Color(nsColor: .windowBackgroundColor),
            glassTintColor: menuGlassTintColor,
            fallbackVisualMaterial: .popover,
            fallbackBlendingMode: .behindWindow,
            topHighlight: Color.white.opacity(colorScheme == .dark ? 0.10 : 0.20),
            middleTint: menuMiddleTint,
            bottomShade: Color.black.opacity(colorScheme == .dark ? 0.08 : 0.03),
            rimColor: Color.white.opacity(colorScheme == .dark ? 0.30 : 0.44),
            shadowColor: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.16),
            useGlassEffect: !prefersSolidSurfaces
        )
        .onReceive(NotificationCenter.default.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )) { _ in
            accessibilityDisplayShouldIncreaseContrast =
                NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }

    private var prefersSolidSurfaces: Bool {
        accessibilityReduceTransparency || accessibilityDisplayShouldIncreaseContrast
    }

    private var menuGlassTintColor: NSColor? {
        colorScheme == .dark
            ? NSColor(calibratedWhite: 0.92, alpha: 0.08)
            : NSColor(calibratedWhite: 1.00, alpha: 0.20)
    }

    private var menuMiddleTint: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color(red: 0.82, green: 0.90, blue: 1.00).opacity(0.08)
    }
}

extension View {
    @ViewBuilder
    func apiInquiryMenuBarGlassPanelBackground() -> some View {
        if #available(macOS 15.0, *) {
            self.containerBackground(for: .window) {
                MenuBarWindowGlassBackground()
            }
        } else {
            self.background {
                MenuBarGlassBackground()
            }
        }
    }
}

private struct MenuBarWindowGlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var accessibilityDisplayShouldIncreaseContrast =
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    var body: some View {
        Group {
            if prefersSolidSurfaces {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
            } else {
                APIInquiryNativeGlassBackdrop(
                    cornerRadius: 0,
                    tintColor: menuGlassTintColor,
                    fallbackMaterial: .popover,
                    fallbackBlendingMode: .behindWindow
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    Rectangle()
                        .fill(menuGlassTone)
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )) { _ in
            accessibilityDisplayShouldIncreaseContrast =
                NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }

    private var prefersSolidSurfaces: Bool {
        accessibilityReduceTransparency || accessibilityDisplayShouldIncreaseContrast
    }

    private var menuGlassTintColor: NSColor? {
        colorScheme == .dark
            ? NSColor(calibratedWhite: 0.92, alpha: 0.08)
            : NSColor(calibratedWhite: 1.00, alpha: 0.18)
    }

    private var menuGlassTone: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.12),
                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.06),
                Color.black.opacity(colorScheme == .dark ? 0.05 : 0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ConsoleNavigationBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var accessibilityDisplayShouldIncreaseContrast =
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    var body: some View {
        APIInquiryGlassSurface(
            cornerRadius: ConsoleMetrics.navigationCornerRadius,
            solidColor: Color.secondary.opacity(0.10),
            glassTintColor: navigationGlassTintColor,
            fallbackVisualMaterial: .hudWindow,
            fallbackBlendingMode: .behindWindow,
            topHighlight: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.24),
            middleTint: navigationMiddleTint,
            bottomShade: Color.black.opacity(colorScheme == .dark ? 0.08 : 0.02),
            rimColor: Color.white.opacity(colorScheme == .dark ? 0.24 : 0.38),
            shadowColor: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.10),
            useGlassEffect: !prefersSolidSurfaces
        )
        .onReceive(NotificationCenter.default.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )) { _ in
            accessibilityDisplayShouldIncreaseContrast =
                NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }

    private var prefersSolidSurfaces: Bool {
        accessibilityReduceTransparency || accessibilityDisplayShouldIncreaseContrast
    }

    private var navigationGlassTintColor: NSColor? {
        colorScheme == .dark
            ? NSColor(calibratedWhite: 0.96, alpha: 0.08)
            : NSColor(calibratedWhite: 1.00, alpha: 0.18)
    }

    private var navigationMiddleTint: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color(red: 0.78, green: 0.90, blue: 1.00).opacity(0.08)
    }
}

struct ConsoleNavigationSelectionBackground: View {
    let isSelected: Bool

    @Environment(\.accessibilityReduceTransparency) private var accessibilityReduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var accessibilityDisplayShouldIncreaseContrast =
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    var body: some View {
        Group {
            if isSelected {
                APIInquiryGlassSurface(
                    cornerRadius: ConsoleMetrics.navigationSelectionCornerRadius,
                    solidColor: Color.accentColor,
                    glassTintColor: selectedGlassTintColor,
                    fallbackVisualMaterial: .selection,
                    fallbackBlendingMode: .withinWindow,
                    topHighlight: Color.white.opacity(0.28),
                    middleTint: Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.14),
                    bottomShade: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.04),
                    rimColor: Color.white.opacity(0.38),
                    shadowColor: Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14),
                    useGlassEffect: !prefersSolidSurfaces,
                    fallbackTint: Color.accentColor.opacity(0.86)
                )
            } else {
                Color.clear
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        )) { _ in
            accessibilityDisplayShouldIncreaseContrast =
                NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        }
    }

    private var prefersSolidSurfaces: Bool {
        accessibilityReduceTransparency || accessibilityDisplayShouldIncreaseContrast
    }

    private var selectedGlassTintColor: NSColor? {
        NSColor.controlAccentColor.withAlphaComponent(colorScheme == .dark ? 0.26 : 0.22)
    }
}

private struct APIInquiryGlassSurface: View {
    let cornerRadius: CGFloat
    let solidColor: Color
    let glassTintColor: NSColor?
    let fallbackVisualMaterial: NSVisualEffectView.Material
    let fallbackBlendingMode: NSVisualEffectView.BlendingMode
    let topHighlight: Color
    let middleTint: Color
    let bottomShade: Color
    let rimColor: Color
    let shadowColor: Color
    let useGlassEffect: Bool
    var fallbackTint: Color = Color.clear

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if useGlassEffect {
                APIInquiryNativeGlassBackdrop(
                    cornerRadius: cornerRadius,
                    tintColor: glassTintColor,
                    fallbackMaterial: fallbackVisualMaterial,
                    fallbackBlendingMode: fallbackBlendingMode
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(shape)
                .overlay {
                    shape.fill(shouldApplyFallbackTint ? fallbackTint : Color.clear)
                }
                .overlay {
                    glassOverlay(shape: shape)
                }
                .overlay {
                    shape.strokeBorder(rimColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: 22, y: 10)
            } else {
                shape
                    .fill(solidColor)
                    .overlay {
                        shape.fill(fallbackTint)
                    }
                    .overlay {
                        shape.strokeBorder(rimColor.opacity(0.75), lineWidth: 1)
                    }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var shouldApplyFallbackTint: Bool {
        if #available(macOS 26.0, *) {
            return false
        }

        return true
    }

    private func glassOverlay(shape: RoundedRectangle) -> some View {
        shape.fill(
            LinearGradient(
                colors: [topHighlight, middleTint, bottomShade],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct APIInquiryNativeGlassBackdrop: NSViewRepresentable {
    let cornerRadius: CGFloat
    let tintColor: NSColor?
    let fallbackMaterial: NSVisualEffectView.Material
    let fallbackBlendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            configure(glassView)
            return glassView
        }

        let effectView = NSVisualEffectView()
        configure(effectView)
        return effectView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26.0, *), let glassView = nsView as? NSGlassEffectView {
            configure(glassView)
        } else if let effectView = nsView as? NSVisualEffectView {
            configure(effectView)
        }
    }

    @available(macOS 26.0, *)
    private func configure(_ glassView: NSGlassEffectView) {
        glassView.style = .regular
        glassView.cornerRadius = cornerRadius
        glassView.tintColor = tintColor
    }

    private func configure(_ effectView: NSVisualEffectView) {
        effectView.material = fallbackMaterial
        effectView.blendingMode = fallbackBlendingMode
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
    }
}
