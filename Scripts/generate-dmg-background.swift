#!/usr/bin/env swift
//
// Draws the DMG install-window background for both languages.
//
// Geometry is not defined here: the window size, icon size and icon positions
// come from Scripts/dmg-layout.env, which package-dmg.sh reads too. Duplicating
// those numbers once cost us a chevron 9.5 pt off the icon midpoint (#107).
//
// Usage: swift Scripts/generate-dmg-background.swift
// Writes Scripts/Assets/dmg-background-zh.png and dmg-background-en.png.

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let layoutURL = rootURL.appendingPathComponent("Scripts/dmg-layout.env")
let versionURL = rootURL.appendingPathComponent("Scripts/version.env")
let assetsURL = rootURL.appendingPathComponent("Scripts/Assets", isDirectory: true)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("generate-dmg-background: \(message)\n".utf8))
    exit(1)
}

func loadEnv(_ url: URL) -> [String: String] {
    guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
        fail("could not read \(url.path)")
    }

    var values: [String: String] = [:]
    for line in contents.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
              let separator = trimmed.firstIndex(of: "=") else { continue }

        let key = String(trimmed[trimmed.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
        var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        values[key] = value
    }
    return values
}

let layout = loadEnv(layoutURL)
let versionValues = loadEnv(versionURL)

func layoutValue(_ key: String) -> CGFloat {
    guard let raw = layout[key], let value = Double(raw), value > 0 else {
        fail("\(layoutURL.lastPathComponent) is missing a positive \(key)")
    }
    return CGFloat(value)
}

// MARK: - geometry (shared with package-dmg.sh)

let width = layoutValue("DMG_WINDOW_WIDTH")
let height = layoutValue("DMG_WINDOW_HEIGHT")
let iconSize = layoutValue("DMG_ICON_SIZE")
let appIconCenter = CGPoint(x: layoutValue("DMG_APP_ICON_X"), y: layoutValue("DMG_APP_ICON_Y"))
let folderIconCenter = CGPoint(x: layoutValue("DMG_FOLDER_ICON_X"), y: layoutValue("DMG_FOLDER_ICON_Y"))
let scale: CGFloat = 2

guard let appVersion = versionValues["APP_VERSION"], !appVersion.isEmpty else {
    fail("version.env is missing APP_VERSION")
}

// MARK: - design tokens

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

enum Palette {
    static let brand = color(58, 109, 232)
    static let ink = color(29, 33, 41)
    static let muted = color(122, 129, 140)
    static let hint = color(128, 136, 148)
    static let cardStroke = color(228, 233, 243)
}

// MARK: - drawing primitives

let iconMidX = (appIconCenter.x + folderIconCenter.x) / 2

/// The chevron sits above the icon centres so the hint below it stays clear of
/// the item labels Finder draws itself.
let arrowCenter = CGPoint(x: iconMidX, y: appIconCenter.y - 10)
let arrowSize: CGFloat = 34
let arrowStroke: CGFloat = 5.2
let arrowOffset = arrowSize * 0.30 + 2

let cardRect = (top: CGFloat(104), left: CGFloat(48), height: CGFloat(216), width: width - 96)

func sized(_ rep: NSBitmapImageRep) -> NSGraphicsContext {
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    return context
}

func blankCanvas() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width * scale),
        pixelsHigh: Int(height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    return rep
}

func point(x: CGFloat, y: CGFloat) -> NSPoint {
    NSPoint(x: x, y: height - y)
}

func rect(top: CGFloat, left: CGFloat, width rectWidth: CGFloat, height rectHeight: CGFloat) -> NSRect {
    NSRect(x: left, y: height - top - rectHeight, width: rectWidth, height: rectHeight)
}

func fillVerticalGradient(_ colors: [NSColor], in rect: NSRect, angle: CGFloat) {
    NSGradient(colors: colors)!.draw(in: rect, angle: angle)
}

/// A top-down brand tint. A radial glow looked the same but encoded to 618 KB
/// instead of 273 KB: a smooth two-dimensional ramp leaves PNG nothing to
/// predict, while one-dimensional ramps compress well.
func fillTintBand(top: CGFloat, height bandHeight: CGFloat, color tint: NSColor) {
    NSGradient(starting: tint, ending: tint.withAlphaComponent(0))!
        .draw(in: rect(top: top, left: 0, width: width, height: bandHeight), angle: -90)
}

/// A field of dots whose alpha fades out with depth, so it reads as texture
/// instead of a grid.
func drawDotField(in rect: NSRect, spacing: CGFloat, radius: CGFloat, color dotColor: NSColor) {
    let context = NSGraphicsContext.current!.cgContext
    var y = rect.minY + spacing / 2
    while y < rect.maxY {
        var x = rect.minX + spacing / 2
        while x < rect.maxX {
            let nx = (x - rect.minX) / rect.width
            let ny = (rect.maxY - y) / rect.height
            let depth = max(0, 1 - ny)
            let ripple = 0.55 + 0.45 * sin(nx * 8.2 + 0.3) * cos(ny * 4.6)
            let alpha = 0.16 * depth * depth * max(0.08, ripple)
            if alpha > 0.001 {
                context.setFillColor(dotColor.withAlphaComponent(alpha).cgColor)
                context.fillEllipse(in: CGRect(x: x - radius, y: y - radius,
                                               width: radius * 2, height: radius * 2))
            }
            x += spacing
        }
        y += spacing
    }
}

func drawCard(_ rect: NSRect) {
    let context = NSGraphicsContext.current!
    let path = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)

    context.saveGraphicsState()
    context.cgContext.setShadow(offset: CGSize(width: 0, height: -3), blur: 22,
                                color: color(24, 40, 80, 0.12).cgColor)
    color(255, 255, 255, 0.97).setFill()
    path.fill()
    context.restoreGraphicsState()

    Palette.cardStroke.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func chevronPath(center: CGPoint, size: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: point(x: center.x - size * 0.30, y: center.y - size * 0.52))
    path.line(to: point(x: center.x + size * 0.30, y: center.y))
    path.line(to: point(x: center.x - size * 0.30, y: center.y + size * 0.52))
    return path
}

/// Strokes both chevrons as one path and fills the stroke with a single
/// horizontal gradient, so the ramp runs continuously across the pair.
/// Light tail, deep head: the opposite direction makes the arrow look erased
/// on its way to the folder.
func drawArrowPair(at center: CGPoint) {
    let context = NSGraphicsContext.current!.cgContext
    let combined = NSBezierPath()
    combined.append(chevronPath(center: CGPoint(x: center.x - arrowOffset, y: center.y), size: arrowSize))
    combined.append(chevronPath(center: CGPoint(x: center.x + arrowOffset, y: center.y), size: arrowSize))

    context.saveGState()
    context.addPath(combined.cgPath)
    context.setLineWidth(arrowStroke)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.replacePathWithStrokedPath()
    context.clip()

    let colors = [color(126, 165, 246).cgColor, color(43, 92, 220).cgColor]
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors as CFArray, locations: nil) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: combined.bounds.minX, y: 0),
                                   end: CGPoint(x: combined.bounds.maxX, y: 0),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    context.restoreGState()
}

func drawCenteredText(_ string: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight,
                      textColor: NSColor, tracking: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: textColor,
        .kern: tracking
    ]
    let text = NSAttributedString(string: string, attributes: attributes)
    text.draw(at: NSPoint(x: width / 2 - text.size().width / 2, y: height - top - text.size().height))
}

// MARK: - languages

struct InstallCopy {
    let assetSuffix: String
    let headline: String
    let headlineTracking: CGFloat
    let hint: String
    let hintTracking: CGFloat
}

let copies = [
    InstallCopy(
        assetSuffix: "zh",
        headline: "更轻量、更原生、更高效的 AI 额度查询工具",
        headlineTracking: 0.4,
        hint: "拖拽安装",
        hintTracking: 1.2
    ),
    InstallCopy(
        assetSuffix: "en",
        headline: "A lighter, more native, faster AI quota viewer",
        headlineTracking: 0.1,
        hint: "Drag to install",
        hintTracking: 0.5
    )
]

// MARK: - render

func render(_ copy: InstallCopy) {
    let rep = blankCanvas()
    let previousContext = NSGraphicsContext.current
    NSGraphicsContext.current = sized(rep)

    let fullRect = NSRect(x: 0, y: 0, width: width, height: height)
    fillVerticalGradient([color(255, 255, 255), color(241, 244, 250)], in: fullRect, angle: -90)
    fillTintBand(top: 0, height: 190, color: color(58, 109, 232, 0.13))
    drawDotField(in: rect(top: 0, left: 0, width: width, height: 118),
                 spacing: 13, radius: 1.4, color: Palette.brand)

    drawCenteredText(copy.headline, top: 26, size: 22, weight: .medium,
                     textColor: Palette.ink, tracking: copy.headlineTracking)
    drawCenteredText("v\(appVersion)", top: 60, size: 11, weight: .medium,
                     textColor: Palette.muted, tracking: 1.4)

    drawCard(rect(top: cardRect.top, left: cardRect.left, width: cardRect.width, height: cardRect.height))

    drawArrowPair(at: arrowCenter)
    drawCenteredText(copy.hint, top: 220, size: 11, weight: .regular,
                     textColor: Palette.hint, tracking: copy.hintTracking)

    NSGraphicsContext.current = previousContext

    let outputURL = assetsURL.appendingPathComponent("dmg-background-\(copy.assetSuffix).png")
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fail("could not encode \(outputURL.lastPathComponent)")
    }
    do {
        try data.write(to: outputURL, options: .atomic)
    } catch {
        fail("could not write \(outputURL.path): \(error.localizedDescription)")
    }
    print("Generated \(outputURL.lastPathComponent) (\(Int(width))x\(Int(height)) @\(Int(scale))x, \(data.count) bytes)")
}

NSGraphicsContext.saveGraphicsState()
for copy in copies {
    render(copy)
}
NSGraphicsContext.restoreGraphicsState()
