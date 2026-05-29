import APIInquiryCore
import AppKit

enum DeepSeekImages {
    static let headerLogoTemplate: NSImage = {
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

    static func headerLogoTemplate(for providerID: ProviderID) -> NSImage? {
        switch providerID {
        case .deepseek:
            return headerLogoTemplate
        case .zhipuCodingPlan:
            return zhipuHeaderLogoTemplate
        case .codex:
            return chatGPTHeaderLogoTemplate
        }
    }

    static func headerLogoSize(for providerID: ProviderID) -> NSSize {
        switch providerID {
        case .deepseek:
            return NSSize(width: 96, height: 21)
        case .zhipuCodingPlan:
            return NSSize(width: 140, height: 29)
        case .codex:
            return NSSize(width: 116, height: 32)
        }
    }

    static func consoleLogoSize(for providerID: ProviderID) -> NSSize {
        switch providerID {
        case .deepseek:
            return NSSize(width: 106, height: 23)
        case .zhipuCodingPlan:
            return NSSize(width: 152, height: 32)
        case .codex:
            return NSSize(width: 108, height: 30)
        }
    }

    static func menuIconSize(for providerID: ProviderID) -> NSSize {
        switch providerID {
        case .deepseek:
            return NSSize(width: 20, height: 20)
        case .zhipuCodingPlan:
            return NSSize(width: 20, height: 18)
        case .codex:
            return NSSize(width: 16, height: 16)
        }
    }

    static func menuBarLabelImage(
        text: String,
        providerID: ProviderID = .deepseek,
        providerPrefix: String = "DS"
    ) -> NSImage {
        let icon = menuIconTemplate(for: providerID)
        let font = NSFont.menuBarFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let height: CGFloat = 22
        let iconSize = menuIconSize(for: providerID)
        let spacing: CGFloat = 4
        let width = ceil(iconSize.width + spacing + textSize.width)
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        if let icon {
            let iconRect = NSRect(x: 0, y: (height - iconSize.height) / 2, width: iconSize.width, height: iconSize.height)
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            drawText(providerPrefix, in: NSRect(x: 0, y: 0, width: iconSize.width, height: height), fontSize: providerPrefix.count > 2 ? 8 : 10, weight: .bold)
        }

        let textRect = NSRect(
            x: iconSize.width + spacing,
            y: floor((height - textSize.height) / 2),
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
        image.unlockFocus()

        image.isTemplate = true
        return image
    }

    private static func menuIconTemplate(for providerID: ProviderID) -> NSImage? {
        switch providerID {
        case .deepseek:
            return loadPNG(named: "deepseek-menu-icon-template")
        case .zhipuCodingPlan:
            return loadPNG(named: "zhipu-menu-icon-template")
        case .codex:
            return loadPNG(named: "chatgpt-menu-icon-template")
        }
    }

    private static func loadPNG(named name: String) -> NSImage? {
        for url in resourceURLs(named: name) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }

    private static func resourceURLs(named name: String) -> [URL] {
        var urls: [URL] = []

        if let mainURL = Bundle.main.url(forResource: name, withExtension: "png") {
            urls.append(mainURL)
        }

        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("APIInquiry_APIInquiryApp.bundle")
        if let resourceBundle = Bundle(url: bundleURL),
           let bundledURL = resourceBundle.url(forResource: name, withExtension: "png") {
            urls.append(bundledURL)
        }

        if urls.isEmpty, let moduleURL = Bundle.module.url(forResource: name, withExtension: "png") {
            urls.append(moduleURL)
        }

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

    private static func drawText(_ text: String, in rect: NSRect, fontSize: CGFloat, weight: NSFont.Weight) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
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
