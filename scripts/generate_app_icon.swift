import Cocoa
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func createMasterIcon() -> CGImage {
    let size = 1024
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to create graphics context")
    }
    
    // Antialiasing
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    // Squircle Dimensions
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 184
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // 1. Drop Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 40, color: NSColor.black.withAlphaComponent(0.38).cgColor)
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    
    // 2. Base Gradient (Deep Indigo -> Vibrant Violet -> Cyan)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    let colors = [
        NSColor(red: 0.12, green: 0.28, blue: 0.88, alpha: 1.0).cgColor, // Royal Blue
        NSColor(red: 0.42, green: 0.20, blue: 0.85, alpha: 1.0).cgColor, // Deep Violet
        NSColor(red: 0.60, green: 0.15, blue: 0.78, alpha: 1.0).cgColor  // Magenta
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.55, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 100, y: 924),
            end: CGPoint(x: 924, y: 100),
            options: []
        )
    }
    
    // 3. Subtle Inner Rim Highlight
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.setLineWidth(4.0)
    ctx.addPath(squirclePath)
    ctx.strokePath()
    
    // 4. Viewfinder / Crop Marks
    // Center area
    let cropRect = CGRect(x: 292, y: 292, width: 440, height: 440)
    let markLength: CGFloat = 84
    let markThickness: CGFloat = 26
    
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(markThickness)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    
    // Top-Left corner
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cropRect.minX, y: cropRect.maxY - markLength))
    ctx.addLine(to: CGPoint(x: cropRect.minX, y: cropRect.maxY))
    ctx.addLine(to: CGPoint(x: cropRect.minX + markLength, y: cropRect.maxY))
    ctx.strokePath()
    
    // Top-Right corner
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cropRect.maxX - markLength, y: cropRect.maxY))
    ctx.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.maxY))
    ctx.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.maxY - markLength))
    ctx.strokePath()
    
    // Bottom-Left corner
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + markLength))
    ctx.addLine(to: CGPoint(x: cropRect.minX, y: cropRect.minY))
    ctx.addLine(to: CGPoint(x: cropRect.minX + markLength, y: cropRect.minY))
    ctx.strokePath()
    
    // Bottom-Right corner
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cropRect.maxX - markLength, y: cropRect.minY))
    ctx.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY))
    ctx.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + markLength))
    ctx.strokePath()
    
    // 5. Stylized Lens & Aperture
    let center = CGPoint(x: cropRect.midX, y: cropRect.midY)
    
    // Outer lens ring
    let lensRadius: CGFloat = 120
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
    ctx.setLineWidth(14.0)
    ctx.strokeEllipse(in: CGRect(x: center.x - lensRadius, y: center.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2))
    
    // Inner glowing core
    let coreRadius: CGFloat = 68
    ctx.setFillColor(NSColor(red: 0.10, green: 0.85, blue: 0.95, alpha: 0.95).cgColor) // Bright Cyan Core
    ctx.fillEllipse(in: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2))
    
    // Center specular reflection
    let specRadius: CGFloat = 20
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 22, y: center.y + 18, width: specRadius * 2, height: specRadius * 2))
    
    // 6. Annotation Pointer / Arrow motif (Accent pointing up-right)
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1.0).cgColor) // Bright Amber
    ctx.setFillColor(NSColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1.0).cgColor)
    ctx.setLineWidth(18.0)
    
    let arrowStart = CGPoint(x: center.x + 40, y: center.y + 40)
    let arrowEnd = CGPoint(x: cropRect.maxX - 24, y: cropRect.maxY - 24)
    ctx.beginPath()
    ctx.move(to: arrowStart)
    ctx.addLine(to: arrowEnd)
    ctx.strokePath()
    
    // Arrow Head
    let headLen: CGFloat = 48
    let angle = atan2(arrowEnd.y - arrowStart.y, arrowEnd.x - arrowStart.x)
    let p1 = CGPoint(x: arrowEnd.x - headLen * cos(angle - .pi / 6), y: arrowEnd.y - headLen * sin(angle - .pi / 6))
    let p2 = CGPoint(x: arrowEnd.x - headLen * cos(angle + .pi / 6), y: arrowEnd.y - headLen * sin(angle + .pi / 6))
    ctx.beginPath()
    ctx.move(to: arrowEnd)
    ctx.addLine(to: p1)
    ctx.addLine(to: p2)
    ctx.closePath()
    ctx.fillPath()
    
    ctx.restoreGState()
    
    guard let master = ctx.makeImage() else {
        fatalError("Failed to generate master CGImage")
    }
    return master
}

func savePNG(image: CGImage, to url: URL, targetWidth: Int, targetHeight: Int) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let ctx = CGContext(
        data: nil,
        width: targetWidth,
        height: targetHeight,
        bitsPerComponent: 8,
        bytesPerRow: targetWidth * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return }
    
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    
    guard let scaled = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return
    }
    CGImageDestinationAddImage(dest, scaled, nil)
    CGImageDestinationFinalize(dest)
}

// MAIN
let masterImage = createMasterIcon()
let fm = FileManager.default
let iconsetDir = URL(fileURLWithPath: "PsrShot.iconset")

try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int, Int)] = [
    ("icon_16x16.png", 16, 16),
    ("icon_16x16@2x.png", 32, 32),
    ("icon_32x32.png", 32, 32),
    ("icon_32x32@2x.png", 64, 64),
    ("icon_128x128.png", 128, 128),
    ("icon_128x128@2x.png", 256, 256),
    ("icon_256x256.png", 256, 256),
    ("icon_256x256@2x.png", 512, 512),
    ("icon_512x512.png", 512, 512),
    ("icon_512x512@2x.png", 1024, 1024)
]

for (filename, w, h) in sizes {
    let fileURL = iconsetDir.appendingPathComponent(filename)
    savePNG(image: masterImage, to: fileURL, targetWidth: w, targetHeight: h)
}

// Run iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "PsrShot.iconset", "-o", "Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()

// Clean up iconset
try? fm.removeItem(at: iconsetDir)
print("Successfully generated Resources/AppIcon.icns!")
