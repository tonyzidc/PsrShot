import Cocoa
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public final class ImageExporter {
    
    public static func renderFinalImage(
        baseImage: CGImage,
        screen: NSScreen,
        cropRect: CGRect,
        annotations: [AnnotationItem]
    ) -> CGImage? {
        let screenWidth = max(1.0, screen.frame.width)
        let screenHeight = max(1.0, screen.frame.height)
        
        let scaleX = CGFloat(baseImage.width) / screenWidth
        let scaleY = CGFloat(baseImage.height) / screenHeight
        
        let pixelWidth = Int(ceil(cropRect.width * scaleX))
        let pixelHeight = Int(ceil(cropRect.height * scaleY))
        
        guard pixelWidth > 0 && pixelHeight > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        // Accurate pixel cropping with strict boundary clamping
        let cropX = max(0.0, min(CGFloat(baseImage.width), cropRect.origin.x * scaleX))
        let cropY = max(0.0, min(CGFloat(baseImage.height), cropRect.origin.y * scaleY))
        let cropW = max(1.0, min(CGFloat(baseImage.width) - cropX, cropRect.width * scaleX))
        let cropH = max(1.0, min(CGFloat(baseImage.height) - cropY, cropRect.height * scaleY))
        
        let pixelCropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        
        if let croppedBase = baseImage.cropping(to: pixelCropRect) {
            context.draw(croppedBase, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        }
        
        // Draw annotations aligned to top-left coordinate system
        context.saveGState()
        context.scaleBy(x: scaleX, y: scaleY)
        context.translateBy(x: -cropRect.origin.x, y: -cropRect.origin.y)
        
        for annotation in annotations {
            annotation.draw(in: context, baseImage: baseImage, scale: (scaleX + scaleY) / 2.0)
        }
        context.restoreGState()
        
        return context.makeImage()
    }
    
    public static func encode(cgImage: CGImage, settings: ImageCompressionSettings) -> Data? {
        let utType = settings.format.utType
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, utType.identifier as CFString, 1, nil) else {
            return nil
        }
        
        var options: [CFString: Any] = [:]
        if settings.isCompressionEnabled {
            options[kCGImageDestinationLossyCompressionQuality] = settings.quality as CFNumber
        }
        
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
    
    public static func copyToPasteboard(cgImage: CGImage, screen: NSScreen? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let scale = screen?.backingScaleFactor ?? 2.0
        let logicalSize = NSSize(
            width: CGFloat(cgImage.width) / scale,
            height: CGFloat(cgImage.height) / scale
        )
        
        let nsImage = NSImage(cgImage: cgImage, size: logicalSize)
        
        // 1. Write as NSImage pasteboard object (ensures full compatibility with Cocoa apps)
        pasteboard.writeObjects([nsImage])
        
        // 2. Write PNG representation directly (for browser/web/electron apps)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }
        
        // 3. Write TIFF representation
        if let tiffData = nsImage.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
    
    public static func saveToDisk(
        cgImage: CGImage,
        settings: ImageCompressionSettings,
        parentWindow: NSWindow?,
        completion: @escaping (Bool) -> Void
    ) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "Screenshot \(timestamp).\(settings.format.fileExtension)"
        savePanel.allowedContentTypes = [settings.format.utType]
        
        let handleResponse = { (response: NSApplication.ModalResponse) in
            if response == .OK, let url = savePanel.url {
                if let data = self.encode(cgImage: cgImage, settings: settings) {
                    do {
                        try data.write(to: url)
                        completion(true)
                        return
                    } catch {
                        NSLog("[ImageExporter] Error saving image: \(error)")
                    }
                }
            }
            completion(false)
        }
        
        if let parent = parentWindow {
            savePanel.beginSheetModal(for: parent, completionHandler: handleResponse)
        } else {
            let response = savePanel.runModal()
            handleResponse(response)
        }
    }
}
