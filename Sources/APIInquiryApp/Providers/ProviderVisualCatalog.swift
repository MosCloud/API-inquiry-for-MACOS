import APIInquiryCore
import AppKit

enum ProviderVisualCatalog {
    static let deepSeekHeaderLogoTemplate: NSImage = {
        let image = loadPNG(named: "deepseek-logo-header") ?? textTemplateImage("deepseek", fontSize: 30, height: 33)
        image.isTemplate = true
        return image
    }()

    static let zhipuHeaderLogoTemplate: NSImage = {
        let image = loadPNG(named: "zhipu-logo-header") ?? textTemplateImage("Zhipu BigModel", fontSize: 24, height: 30)
        image.isTemplate = true
        return image
    }()

    static let chatGPTHeaderLogoTemplate: NSImage = {
        let image = loadPNG(named: "chatgpt-logo-header") ?? textTemplateImage("OpenAI", fontSize: 24, height: 30)
        image.isTemplate = true
        return image
    }()

    /// OpenCode brand lockup: the official mark (`opencode-logo-dark.svg`) composed with
    /// the official wordmark (`opencode-wordmark-simple-dark.svg`), both MIT licensed,
    /// © 2025 opencode. Source: github.com/anomalyco/opencode,
    /// packages/console/app/src/asset/brand/. Re-rasterised as `opencode-logo-header.svg`.
    static let openCodeHeaderLogoTemplate: NSImage = {
        // Load the vector asset so the pixel-block wordmark rasterises at the exact
        // frame size; a pre-shrunk PNG loses the block edges when macOS resamples it.
        let image = loadVector(named: "opencode-logo-header")
            ?? loadPNG(named: "opencode-logo-header")
            ?? textTemplateImage("OpenCode", fontSize: 24, height: 30)
        image.isTemplate = true
        return image
    }()

    static func headerLogoTemplate(for providerID: ProviderID) -> NSImage? {
        switch providerID {
        case .deepseek:
            return deepSeekHeaderLogoTemplate
        case .zhipuCodingPlan:
            return zhipuHeaderLogoTemplate
        case .codex:
            return chatGPTHeaderLogoTemplate
        case .opencode:
            return openCodeHeaderLogoTemplate
        }
    }

    static func headerLogoSize(for providerID: ProviderID) -> NSSize {
        logoSize(for: providerID, on: .menuPanel)
    }

    static func consoleLogoSize(for providerID: ProviderID) -> NSSize {
        logoSize(for: providerID, on: .console)
    }

    /// Sizes every lockup so its wordmark renders at the surface's target height,
    /// instead of hand-tuned per-provider frames that left the wordmarks at four
    /// different visual sizes.
    private static func logoSize(for providerID: ProviderID, on surface: ProviderLogoSurface) -> NSSize {
        guard let size = ProviderLogoMetrics.size(for: providerID, on: surface) else {
            return NSSize(width: 96, height: 21)
        }
        // Whole-point frames keep the template image on the pixel grid; fractional
        // sizes smear the lockup's hard edges when macOS resamples it.
        return NSSize(width: size.width.rounded(), height: size.height.rounded())
    }

    static func menuIconSize(for providerID: ProviderID) -> NSSize {
        switch providerID {
        case .deepseek:
            return NSSize(width: 20, height: 20)
        case .zhipuCodingPlan:
            return NSSize(width: 20, height: 18)
        case .codex:
            return NSSize(width: 16, height: 16)
        case .opencode:
            return NSSize(width: 16, height: 16)
        }
    }

    /// Builds the menu bar label as one image. The stale marker lives inside the image
    /// because a `MenuBarExtra` label only renders one view: a second image in an HStack
    /// never appears.
    static func menuBarLabelImage(
        text: String,
        providerID: ProviderID = .deepseek,
        providerPrefix: String = "DS",
        isStale: Bool = false
    ) -> NSImage {
        let icon = menuIconTemplate(for: providerID)
        let font = NSFont.menuBarFont(ofSize: 0)
        let textColor: NSColor = isStale ? .labelColor : .white
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let height: CGFloat = 22
        let iconSize = menuIconSize(for: providerID)
        let spacing: CGFloat = 4
        let markerSpacing: CGFloat = isStale ? 2 : 0
        let markerTrailingPadding: CGFloat = isStale ? 5 : 0
        let markerFont = NSFont.systemFont(ofSize: 13, weight: .bold)
        let marker = "!" as NSString
        let markerAttributes: [NSAttributedString.Key: Any] = [
            .font: markerFont,
            .foregroundColor: NSColor.systemRed
        ]
        let markerSize = marker.size(withAttributes: markerAttributes)
        let markerWidth = isStale ? markerSize.width : 0
        let width = ceil(iconSize.width + spacing + textSize.width + markerSpacing + markerWidth + markerTrailingPadding)
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        if let icon {
            let iconRect = NSRect(x: 0, y: (height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height)
            let drawable = isStale ? tinted(icon, color: textColor) : icon
            drawable.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            drawText(
                providerPrefix,
                in: NSRect(x: 0, y: 0, width: iconSize.width, height: height),
                fontSize: providerPrefix.count > 2 ? 8 : 10,
                weight: .bold,
                color: textColor
            )
        }

        let textRect = NSRect(
            x: iconSize.width + spacing,
            y: floor((height - textSize.height) / 2),
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)

        if isStale {
            let markerRect = NSRect(
                x: iconSize.width + spacing + textSize.width + markerSpacing,
                y: floor((height - markerSize.height) / 2),
                width: markerSize.width,
                height: markerSize.height
            )
            marker.draw(in: markerRect, withAttributes: markerAttributes)
        }

        image.unlockFocus()

        image.isTemplate = !isStale
        return image
    }

    /// Recolours a template image for the non-template stale label.
    private static func tinted(_ image: NSImage, color: NSColor) -> NSImage {
        let tinted = NSImage(size: image.size)
        tinted.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }

    private static func menuIconTemplate(for providerID: ProviderID) -> NSImage? {
        switch providerID {
        case .deepseek:
            return loadPNG(named: "deepseek-menu-icon-template")
        case .zhipuCodingPlan:
            return loadPNG(named: "zhipu-menu-icon-template")
        case .codex:
            return loadPNG(named: "chatgpt-menu-icon-template")
        case .opencode:
            return loadPNG(named: "opencode-menu-icon-template")
        }
    }

    /// Loads an SVG asset. AppKit keeps it vector-backed, so the image is rasterised
    /// at the size SwiftUI actually draws it at instead of being resampled.
    private static func loadVector(named name: String) -> NSImage? {
        for url in resourceURLs(named: name, extension: "svg") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private static func loadPNG(named name: String) -> NSImage? {
        for url in resourceURLs(named: name) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private static func resourceURLs(named name: String, extension ext: String = "png") -> [URL] {
        var urls: [URL] = []

        if let mainURL = Bundle.main.url(forResource: name, withExtension: ext) {
            urls.append(mainURL)
        }

        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("APIInquiry_APIInquiryApp.bundle")
        if let resourceBundle = Bundle(url: bundleURL),
           let bundledURL = resourceBundle.url(forResource: name, withExtension: ext) {
            urls.append(bundledURL)
        }

        // Do not fall back to `Bundle.module`: SwiftPM's generated accessor calls
        // fatalError when the resource bundle is not next to the executable, and the
        // packaged app flattens the resources into Bundle.main instead. Missing images
        // must stay optional so provider views can fall back to text.
        return urls
    }

    private static func textTemplateImage(_ text: String, fontSize: CGFloat, height: CGFloat) -> NSImage {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let image = NSImage(size: NSSize(width: ceil(textSize.width), height: height))

        image.lockFocus()
        let textRect = NSRect(x: 0, y: floor((height - textSize.height) / 2), width: textSize.width, height: textSize.height)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
        image.unlockFocus()

        image.isTemplate = true
        return image
    }

    private static func drawText(
        _ text: String,
        in rect: NSRect,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor = .white
    ) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }

}
