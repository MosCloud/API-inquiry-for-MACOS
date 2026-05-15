#!/usr/bin/env swift
import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Sources/APIInquiryApp/Resources", isDirectory: true)
let iconSetURL = rootURL.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)
let previewIconURL = resourcesURL.appendingPathComponent("AppIcon.png")
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
let sourceSymbolURL = rootURL.appendingPathComponent("Scripts/Assets/deepseek-app-symbol-source.png")
let fallbackSymbolURL = resourcesURL.appendingPathComponent("deepseek-menu-icon-template.png")

struct IconError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func savePNG(_ representation: NSBitmapImageRep, to url: URL) throws {
    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw IconError(message: "Could not encode PNG for \(url.path)")
    }
    try data.write(to: url, options: .atomic)
}

func bitmapRepresentation(from image: NSImage) -> NSBitmapImageRep? {
    if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
        return bitmap
    }

    guard let tiffData = image.tiffRepresentation else {
        return nil
    }

    return NSBitmapImageRep(data: tiffData)
}

func foregroundAlpha(from color: NSColor, hasTransparentBackground: Bool) -> CGFloat {
    guard let deviceColor = color.usingColorSpace(.deviceRGB) else {
        return 0
    }

    let alpha = deviceColor.alphaComponent
    guard alpha > 0.03 else {
        return 0
    }

    if hasTransparentBackground {
        return alpha
    }

    let red = deviceColor.redComponent
    let green = deviceColor.greenComponent
    let blue = deviceColor.blueComponent
    let distanceFromWhite = max(0, 1 - min(red, green, blue))
    let cleanedDistance = max(0, distanceFromWhite - 0.07)
    return min(1, cleanedDistance * 3.2) * alpha
}

func makeWhiteSymbolImage(from url: URL) throws -> NSImage {
    guard let sourceImage = NSImage(contentsOf: url),
          let source = bitmapRepresentation(from: sourceImage) else {
        throw IconError(message: "Could not load symbol source \(url.path)")
    }

    let width = source.pixelsWide
    let height = source.pixelsHigh
    var hasTransparentBackground = false

    for y in 0..<height {
        for x in 0..<width {
            if (source.colorAt(x: x, y: y)?.alphaComponent ?? 0) < 0.03 {
                hasTransparentBackground = true
                break
            }
        }
        if hasTransparentBackground {
            break
        }
    }

    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0

    for y in 0..<height {
        for x in 0..<width {
            guard let color = source.colorAt(x: x, y: y) else {
                continue
            }
            if foregroundAlpha(from: color, hasTransparentBackground: hasTransparentBackground) > 0.045 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard minX <= maxX, minY <= maxY else {
        return sourceImage
    }

    let padding = max(8, Int(round(CGFloat(max(maxX - minX, maxY - minY)) * 0.035)))
    let cropMinX = max(0, minX - padding)
    let cropMinY = max(0, minY - padding)
    let cropMaxX = min(width - 1, maxX + padding)
    let cropMaxY = min(height - 1, maxY + padding)
    let cropWidth = cropMaxX - cropMinX + 1
    let cropHeight = cropMaxY - cropMinY + 1

    guard let output = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: cropWidth,
        pixelsHigh: cropHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError(message: "Could not create symbol bitmap")
    }
    output.size = NSSize(width: cropWidth, height: cropHeight)

    for y in 0..<cropHeight {
        for x in 0..<cropWidth {
            let sourceX = cropMinX + x
            let sourceY = cropMinY + y
            let alpha = source.colorAt(x: sourceX, y: sourceY)
                .map { foregroundAlpha(from: $0, hasTransparentBackground: hasTransparentBackground) } ?? 0
            output.setColor(NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: alpha), atX: x, y: y)
        }
    }

    let image = NSImage(size: NSSize(width: cropWidth, height: cropHeight))
    image.addRepresentation(output)
    return image
}

func makeCanvas(size: Int) throws -> NSBitmapImageRep {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError(message: "Could not create bitmap canvas")
    }

    representation.size = NSSize(width: size, height: size)
    return representation
}

func drawAppIcon(size: Int, whaleImage: NSImage) throws -> NSBitmapImageRep {
    let representation = try makeCanvas(size: size)
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: representation) else {
        throw IconError(message: "Could not create graphics context")
    }

    let scale = CGFloat(size) / 1024
    let canvas = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    let iconRect = canvas.insetBy(dx: 54 * scale, dy: 54 * scale)
    let cornerRadius = 216 * scale

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.cgContext.clear(canvas)
    graphicsContext.imageInterpolation = .high
    graphicsContext.shouldAntialias = true

    let basePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.shadowBlurRadius = 46 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.set()
    color(22, 42, 122).setFill()
    basePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    basePath.addClip()

    let gradient = NSGradient(colorsAndLocations:
        (color(95, 128, 255), 0.0),
        (color(54, 94, 232), 0.38),
        (color(26, 58, 178), 0.72),
        (color(12, 29, 92), 1.0)
    )
    gradient?.draw(in: iconRect, angle: 90)

    let glowPath = NSBezierPath(ovalIn: CGRect(
        x: iconRect.minX + 96 * scale,
        y: iconRect.maxY - 420 * scale,
        width: 520 * scale,
        height: 360 * scale
    ))
    color(255, 255, 255, 0.20).setFill()
    glowPath.fill()

    let depthPath = NSBezierPath(ovalIn: CGRect(
        x: iconRect.maxX - 420 * scale,
        y: iconRect.minY - 230 * scale,
        width: 560 * scale,
        height: 420 * scale
    ))
    color(0, 7, 38, 0.22).setFill()
    depthPath.fill()

    NSGraphicsContext.restoreGraphicsState()

    color(255, 255, 255, 0.18).setStroke()
    basePath.lineWidth = 3 * scale
    basePath.stroke()

    let whaleRect = CGRect(
        x: iconRect.midX - 322 * scale,
        y: iconRect.midY - 238 * scale,
        width: 560 * scale,
        height: 560 * scale
    )
    graphicsContext.cgContext.setShadow(
        offset: CGSize(width: 0, height: -12 * scale),
        blur: 24 * scale,
        color: NSColor.black.withAlphaComponent(0.24).cgColor
    )
    whaleImage.draw(in: whaleRect, from: .zero, operation: .sourceOver, fraction: 0.98)
    graphicsContext.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

    let chipRect = CGRect(
        x: iconRect.maxX - 312 * scale,
        y: iconRect.minY + 138 * scale,
        width: 240 * scale,
        height: 184 * scale
    )
    let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: 54 * scale, yRadius: 54 * scale)
    NSGraphicsContext.saveGraphicsState()
    let chipShadow = NSShadow()
    chipShadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    chipShadow.shadowBlurRadius = 22 * scale
    chipShadow.shadowOffset = NSSize(width: 0, height: -7 * scale)
    chipShadow.set()
    color(255, 255, 255, 0.18).setFill()
    chipPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    color(255, 255, 255, 0.30).setStroke()
    chipPath.lineWidth = 2 * scale
    chipPath.stroke()

    let barBottom = chipRect.minY + 38 * scale
    let barWidth = 32 * scale
    let barGap = 22 * scale
    let barStartX = chipRect.minX + 55 * scale
    let barHeights = [58 * scale, 96 * scale, 126 * scale]
    for (index, height) in barHeights.enumerated() {
        let barRect = CGRect(
            x: barStartX + CGFloat(index) * (barWidth + barGap),
            y: barBottom,
            width: barWidth,
            height: height
        )
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: 12 * scale, yRadius: 12 * scale)
        let barColor = index == 2 ? color(157, 229, 255, 0.96) : color(255, 255, 255, 0.92)
        barColor.setFill()
        barPath.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return representation
}

func writeIconSet(whaleImage: NSImage) throws {
    if fileManager.fileExists(atPath: iconSetURL.path) {
        try fileManager.removeItem(at: iconSetURL)
    }
    try fileManager.createDirectory(at: iconSetURL, withIntermediateDirectories: true)

    let files: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (fileName, size) in files {
        let representation = try drawAppIcon(size: size, whaleImage: whaleImage)
        try savePNG(representation, to: iconSetURL.appendingPathComponent(fileName))
    }
}

func makeICNS() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", "-o", icnsURL.path, iconSetURL.path]
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw IconError(message: "iconutil failed with status \(process.terminationStatus)")
    }
}

let symbolURL = fileManager.fileExists(atPath: sourceSymbolURL.path) ? sourceSymbolURL : fallbackSymbolURL
let whaleImage = try makeWhiteSymbolImage(from: symbolURL)

try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try writeIconSet(whaleImage: whaleImage)
try savePNG(try drawAppIcon(size: 1024, whaleImage: whaleImage), to: previewIconURL)
try makeICNS()

print("Generated \(previewIconURL.path)")
print("Generated \(icnsURL.path)")
