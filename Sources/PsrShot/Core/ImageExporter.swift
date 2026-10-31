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
        let scale = screen.backingScaleFactor
        let pixelWidth = Int(ceil(cropRect.width * scale))
        let pixelHeight = Int(ceil(cropRect.height * scale))
        
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
        
        // Context setup: AppKit coordinates have origin at top-left when flipped
        // In CGContext, drawing an image draws it right side up if transformed
        let pixelCropRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: CGFloat(pixelWidth),
            height: CGFloat(pixelHeight)
        )
        
        if let croppedBase = baseImage.cropping(to: pixelCropRect) {
            context.draw(croppedBase, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        }
        
        // Translate and scale for drawing annotations in points
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -cropRect.origin.x, y: -cropRect.origin.y)
        
        for annotation in annotations {
            annotation.draw(in: context, baseImage: baseImage, scale: scale)
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
    
    public static func copyToPasteboard(cgImage: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Write TIFF representation
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let tiffData = bitmapRep.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
        // Write PNG representation
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
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
        dateFormatter.dateFormat = "yyyy-MM-dd 'tai' HH.mm.ss"
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
