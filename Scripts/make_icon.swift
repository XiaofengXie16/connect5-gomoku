#!/usr/bin/env swift
// Generates Connect5.app/Contents/Resources/AppIcon.icns
import AppKit
import CoreGraphics

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/AppIcon.icns"

let iconsetPath = "/tmp/Connect5_iconset.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Background: rounded square with wood color
    let radius = s * 0.22
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Wood gradient
    let colors = [
        CGColor(red: 0.88, green: 0.69, blue: 0.35, alpha: 1),
        CGColor(red: 0.74, green: 0.53, blue: 0.22, alpha: 1),
    ] as CFArray
    let locs: [CGFloat] = [0, 1]
    let space = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: space, colors: colors, locations: locs)!

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: s, y: 0),
        options: [])

    // Grid lines (4x4 visible grid)
    let margin = s * 0.13
    let gridSize = s - margin * 2
    let step = gridSize / 4
    let lineColor = CGColor(red: 0.28, green: 0.16, blue: 0.04, alpha: 0.75)
    ctx.setStrokeColor(lineColor)
    ctx.setLineWidth(max(1, s * 0.022))

    for i in 0...4 {
        let pos = margin + CGFloat(i) * step
        ctx.move(to: CGPoint(x: margin, y: pos))
        ctx.addLine(to: CGPoint(x: margin + gridSize, y: pos))
        ctx.move(to: CGPoint(x: pos, y: margin))
        ctx.addLine(to: CGPoint(x: pos, y: margin + gridSize))
    }
    ctx.strokePath()

    // Draw stones
    let stoneR = s * 0.095
    let stones: [(CGFloat, CGFloat, Bool)] = [
        (0.325, 0.325, true),
        (0.545, 0.325, false),
        (0.545, 0.545, true),
        (0.325, 0.545, false),
        (0.435, 0.435, true),  // center black
    ]

    for (rx, ry, isBlack) in stones {
        let cx = s * rx
        let cy = s * ry
        let sr = CGRect(x: cx - stoneR, y: cy - stoneR, width: stoneR * 2, height: stoneR * 2)

        // Shadow
        ctx.setShadow(offset: CGSize(width: stoneR * 0.15, height: -stoneR * 0.2),
                      blur: stoneR * 0.35,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))

        // Stone
        let stoneColors: CFArray
        if isBlack {
            stoneColors = [
                CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1),
                CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1),
            ] as CFArray
        } else {
            stoneColors = [
                CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                CGColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1),
            ] as CFArray
        }
        let sg = CGGradient(colorsSpace: space, colors: stoneColors, locations: locs)!
        ctx.addEllipse(in: sr)
        ctx.clip()
        ctx.drawRadialGradient(sg,
            startCenter: CGPoint(x: cx - stoneR * 0.25, y: cy + stoneR * 0.25),
            startRadius: 0,
            endCenter: CGPoint(x: cx, y: cy),
            endRadius: stoneR,
            options: [])

        // Reset clip
        ctx.resetClip()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
    }

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

// Generate all required sizes
let sizePairs: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (sz, name) in sizePairs {
    let data = drawIcon(size: sz)
    let url = URL(fileURLWithPath: "\(iconsetPath)/\(name).png")
    try! data.write(to: url)
}

// Convert to .icns
let result = Process()
result.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
result.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
try! result.run()
result.waitUntilExit()

try? FileManager.default.removeItem(atPath: iconsetPath)
print("Icon created: \(outputPath)")
