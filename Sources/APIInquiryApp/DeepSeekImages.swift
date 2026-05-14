import AppKit

enum DeepSeekImages {
    static let headerLogoTemplate: NSImage = {
        let image = loadPNG(named: "deepseek-logo-header") ?? textTemplateImage("deepseek", fontSize: 30, height: 33)
        image.isTemplate = true
        return image
    }()

    static func menuBarLabelImage(text: String) -> NSImage {
        let icon = loadPNG(named: "deepseek-menu-icon-template")
        let font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let height: CGFloat = 20
        let iconSize: CGFloat = 18
        let spacing: CGFloat = 4
        let width = ceil(iconSize + spacing + textSize.width)
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        if let icon {
            let iconRect = NSRect(x: 0, y: (height - iconSize) / 2, width: iconSize, height: iconSize)
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            drawText("DS", in: NSRect(x: 0, y: 0, width: iconSize, height: height), fontSize: 10, weight: .bold)
        }

        let textRect = NSRect(
            x: iconSize + spacing,
            y: floor((height - textSize.height) / 2),
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
        image.unlockFocus()

        image.isTemplate = true
        return image
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

        if let moduleURL = Bundle.module.url(forResource: name, withExtension: "png") {
            urls.append(moduleURL)
        }

        if let mainURL = Bundle.main.url(forResource: name, withExtension: "png") {
            urls.append(mainURL)
        }

        let bundleURL = Bundle.main.bundleURL.appendingPathComponent("APIInquiry_APIInquiryApp.bundle")
        if let resourceBundle = Bundle(url: bundleURL),
           let bundledURL = resourceBundle.url(forResource: name, withExtension: "png") {
            urls.append(bundledURL)
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
