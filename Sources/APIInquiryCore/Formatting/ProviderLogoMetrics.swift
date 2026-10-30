import Foundation

/// The surface a provider lockup is drawn on. Both surfaces anchor on the same
/// measurement — the wordmark's x-height — so every provider's lettering reads at
/// one optical size regardless of its typeface.
public enum ProviderLogoSurface: String, CaseIterable, Sendable {
    case menuPanel
    case console

    /// Rendered x-height, in points, for the provider wordmark.
    public var xHeight: Double {
        switch self {
        case .menuPanel, .console:
            return 7.45
        }
    }
}

/// A provider's lockup asset, measured in the asset's own pixel space.
///
/// `xHeight` is the height of the small letters (the band carrying most of the ink),
/// measured from the PNG's alpha channel. `wordmarkHeight` is the full ink height of
/// the lettering. Anchoring on `xHeight` instead of `wordmarkHeight` matters because
/// all-lowercase, mixed-case, and pixel-block typefaces pack very different amounts of
/// ascender/descender into the same bounding box.
public struct ProviderLogoTemplate: Equatable, Sendable {
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let wordmarkHeight: Double
    public let xHeight: Double
    /// Optical correction for typefaces whose weight or contrast makes them read
    /// larger than a regular grotesque at the same x-height (OpenCode ships a heavy
    /// pixel-block wordmark, so it gets a value below 1).
    public let visualScale: Double

    public init(
        canvasWidth: Double,
        canvasHeight: Double,
        wordmarkHeight: Double,
        xHeight: Double,
        visualScale: Double = 1
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.wordmarkHeight = wordmarkHeight
        self.xHeight = xHeight
        self.visualScale = visualScale
    }

    /// Size the image must be laid out at so its x-height renders at `target`.
    public func size(forXHeight target: Double) -> (width: Double, height: Double) {
        guard xHeight > 0 else { return (canvasWidth, canvasHeight) }
        let scale = (target * visualScale) / xHeight
        return (canvasWidth * scale, canvasHeight * scale)
    }
}

public enum ProviderLogoMetrics {
    /// Measured once per asset from the shipped image (see `ProviderVisualCatalog` for
    /// per-asset provenance; the OpenCode lockup is composed from the official MIT-licensed
    /// SVG brand assets rather than redrawn). `xHeight` comes from the row ink
    /// profile of the wordmark (rows holding >=55% of peak ink); keep these in sync
    /// whenever an asset is replaced.
    public static func template(for providerID: ProviderID) -> ProviderLogoTemplate? {
        switch providerID {
        case .deepseek:
            return ProviderLogoTemplate(canvasWidth: 624, canvasHeight: 132, wordmarkHeight: 82, xHeight: 47)
        case .zhipuCodingPlan:
            return ProviderLogoTemplate(canvasWidth: 348, canvasHeight: 72, wordmarkHeight: 38, xHeight: 20)
        case .codex:
            // The OpenAI mark reads optically smaller than DeepSeek's at the same
            // wordmark height (19.5pt vs 21pt in the console chip), so it gets a small
            // upward correction; the wordmark scales with it.
            return ProviderLogoTemplate(
                canvasWidth: 540, canvasHeight: 150, wordmarkHeight: 87, xHeight: 49,
                visualScale: 1.08
            )
        case .opencode:
            return ProviderLogoTemplate(
                canvasWidth: 539, canvasHeight: 154, wordmarkHeight: 70, xHeight: 50,
                visualScale: 1.15
            )
        }
    }

    public static func size(
        for providerID: ProviderID,
        on surface: ProviderLogoSurface
    ) -> (width: Double, height: Double)? {
        template(for: providerID)?.size(forXHeight: surface.xHeight)
    }
}
