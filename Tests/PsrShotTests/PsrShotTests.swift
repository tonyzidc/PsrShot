import XCTest
import CoreGraphics
import Cocoa
import Carbon
@testable import PsrShot

final class PsrShotTests: XCTestCase {
    
    func testSelectionHandleRects() {
        let selection = CGRect(x: 100, y: 100, width: 200, height: 150)
        let handleSize = SelectionHandle.handleSize
        
        let tl = SelectionHandle.topLeft.rect(for: selection)
        XCTAssertEqual(tl.origin.x, 100 - handleSize / 2)
        XCTAssertEqual(tl.origin.y, 100 - handleSize / 2)
        XCTAssertEqual(tl.width, handleSize)
        XCTAssertEqual(tl.height, handleSize)
        
        let br = SelectionHandle.bottomRight.rect(for: selection)
        XCTAssertEqual(br.origin.x, 300 - handleSize / 2)
        XCTAssertEqual(br.origin.y, 250 - handleSize / 2)
        
        let tc = SelectionHandle.topCenter.rect(for: selection)
        XCTAssertEqual(tc.origin.x, 200 - handleSize / 2)
        XCTAssertEqual(tc.origin.y, 100 - handleSize / 2)
    }
    
    func testSelectionHandleHitTesting() {
        let selection = CGRect(x: 100, y: 100, width: 200, height: 150)
        
        let handleAtTL = SelectionHandle.handle(at: CGPoint(x: 100, y: 100), in: selection)
        XCTAssertEqual(handleAtTL, .topLeft)
        
        let handleAtBR = SelectionHandle.handle(at: CGPoint(x: 300, y: 250), in: selection)
        XCTAssertEqual(handleAtBR, .bottomRight)
        
        let handleAtCenter = SelectionHandle.handle(at: CGPoint(x: 200, y: 175), in: selection)
        XCTAssertNil(handleAtCenter)
    }
    
    func testSelectionHandleResizing() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        
        let updatedBR = SelectionHandle.bottomRight.updatedRect(original: original, currentPoint: CGPoint(x: 350, y: 300))
        XCTAssertEqual(updatedBR.origin.x, 100)
        XCTAssertEqual(updatedBR.origin.y, 100)
        XCTAssertEqual(updatedBR.width, 250)
        XCTAssertEqual(updatedBR.height, 200)
        
        let updatedTL = SelectionHandle.topLeft.updatedRect(original: original, currentPoint: CGPoint(x: 80, y: 70))
        XCTAssertEqual(updatedTL.origin.x, 80)
        XCTAssertEqual(updatedTL.origin.y, 70)
        XCTAssertEqual(updatedTL.maxX, 300)
        XCTAssertEqual(updatedTL.maxY, 250)
    }
    
    func testImageExportFormats() {
        XCTAssertEqual(ImageExportFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageExportFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ImageExportFormat.webp.fileExtension, "webp")
        XCTAssertEqual(ImageExportFormat.heic.fileExtension, "heic")
        
        XCTAssertEqual(ImageExportFormat.png.mimeType, "image/png")
        XCTAssertEqual(ImageExportFormat.jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(ImageExportFormat.webp.mimeType, "image/webp")
        XCTAssertEqual(ImageExportFormat.heic.mimeType, "image/heic")
    }
    
    func testImageCompressionSettingsSerialization() throws {
        let settings = ImageCompressionSettings(
            format: .jpeg,
            isCompressionEnabled: true,
            quality: 0.75
        )
        
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ImageCompressionSettings.self, from: data)
        
        XCTAssertEqual(decoded.format, .jpeg)
        XCTAssertTrue(decoded.isCompressionEnabled)
        XCTAssertEqual(decoded.quality, 0.75)
    }
    
    func testS3Configuration() throws {
        var config = S3Config()
        XCTAssertFalse(config.isConfigured)
        
        config.bucket = "my-bucket"
        config.accessKeyId = "AKIA123"
        config.secretAccessKey = "SECRET456"
        XCTAssertTrue(config.isConfigured)
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(S3Config.self, from: data)
        XCTAssertEqual(decoded, config)
    }
    
    func testS3SigV4Signer() {
        let config = S3Config(
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "test-bucket",
            accessKeyId: "TESTKEY",
            secretAccessKey: "TESTSECRET"
        )
        let url = URL(string: "https://test-bucket.s3.us-east-1.amazonaws.com/test.png")!
        let payload = "fake-image-bytes".data(using: .utf8)!
        
        let headers = S3SigV4Signer.sign(
            method: "PUT",
            url: url,
            payload: payload,
            contentType: "image/png",
            config: config,
            date: Date(timeIntervalSince1970: 1700000000)
        )
        
        XCTAssertTrue(headers["Authorization"]?.contains("AWS4-HMAC-SHA256") == true)
        XCTAssertTrue(headers["Authorization"]?.contains("Credential=TESTKEY") == true)
        XCTAssertNotNil(headers["x-amz-content-sha256"])
        XCTAssertNotNil(headers["x-amz-date"])
        XCTAssertEqual(headers["Content-Type"], "image/png")
    }
    
    func testS3UnconfiguredUploadError() {
        UserDefaults.standard.removeObject(forKey: "psrshot_s3_storage_configuration")
        let expectation = self.expectation(description: "Upload fails when unconfigured")
        
        S3Uploader.shared.upload(
            imageData: "test".data(using: .utf8)!,
            mimeType: "image/png",
            fileExtension: "png"
        ) { result in
            switch result {
            case .success:
                XCTFail("Upload should fail when S3 is not configured")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("S3 storage is not configured"))
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testHotkeyManagerHelpers() {
        let cmdShiftFlags: NSEvent.ModifierFlags = [.command, .shift]
        let carbonMods = HotkeyManager.carbonModifiers(from: cmdShiftFlags)
        XCTAssertNotEqual(carbonMods & UInt32(cmdKey), 0)
        XCTAssertNotEqual(carbonMods & UInt32(shiftKey), 0)
        XCTAssertEqual(carbonMods & UInt32(optionKey), 0)
        
        let display = HotkeyManager.displayString(keyCode: UInt32(kVK_ANSI_X), carbonModifiers: carbonMods)
        XCTAssertEqual(display, "⇧⌘X")
    }
    
    func testImageExporterRendering() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: 200,
            height: 200,
            bitsPerComponent: 8,
            bytesPerRow: 800,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let baseImage = ctx.makeImage()!
        
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let crop = CGRect(x: 10, y: 10, width: 80, height: 60)
        
        let annotations: [AnnotationItem] = [
            .shape(type: .rectangle, rect: CGRect(x: 15, y: 15, width: 40, height: 30), color: .red, strokeWidth: 2),
            .arrow(type: .single, start: CGPoint(x: 20, y: 20), end: CGPoint(x: 60, y: 50), color: .blue, strokeWidth: 3)
        ]
        
        let rendered = ImageExporter.renderFinalImage(
            baseImage: baseImage,
            screen: screen,
            cropRect: crop,
            annotations: annotations
        )
        
        XCTAssertNotNil(rendered)
        if let rendered = rendered {
            XCTAssertGreaterThan(rendered.width, 0)
            XCTAssertGreaterThan(rendered.height, 0)
        }
    }
    
    func testColorSwatchButtonSetup() {
        let whiteSwatch = ColorSwatchButton(color: .white, tooltip: "White Color", target: nil, action: #selector(NSObject.description))
        let redSwatch = ColorSwatchButton(color: .systemRed, tooltip: "Red Color", target: nil, action: #selector(NSObject.description))
        
        XCTAssertEqual(whiteSwatch.swatchColor, .white)
        XCTAssertFalse(whiteSwatch.isSwatchSelected)
        
        whiteSwatch.isSwatchSelected = true
        XCTAssertTrue(whiteSwatch.isSwatchSelected)
        XCTAssertEqual(redSwatch.swatchColor, .systemRed)
    }
    
    func testPenDownsamplingMath() {
        let p1 = CGPoint(x: 100, y: 100)
        let p2 = CGPoint(x: 101, y: 101)
        let p3 = CGPoint(x: 105, y: 105)
        
        let d1_2 = hypot(p2.x - p1.x, p2.y - p1.y)
        let d1_3 = hypot(p3.x - p1.x, p3.y - p1.y)
        
        XCTAssertLessThan(d1_2, 2.5)
        XCTAssertGreaterThanOrEqual(d1_3, 2.5)
    }
    
    func testShapeVariants() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 80)
        let shapes: [ShapeType] = [.rectangle, .roundedRect, .ellipse, .filledRect]
        
        for shape in shapes {
            XCTAssertFalse(shape.rawValue.isEmpty)
            XCTAssertFalse(shape.iconSymbol.isEmpty)
            
            let item = AnnotationItem.shape(type: shape, rect: rect, color: .systemBlue, strokeWidth: 3)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let ctx = CGContext(data: nil, width: 100, height: 80, bitsPerComponent: 8, bytesPerRow: 400, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            item.draw(in: ctx)
            XCTAssertNotNil(ctx.makeImage())
        }
    }
    
    func testArrowVariants() {
        let start = CGPoint(x: 10, y: 10)
        let end = CGPoint(x: 90, y: 70)
        let arrows: [ArrowType] = [.single, .double, .line, .dashed]
        
        for arrow in arrows {
            XCTAssertFalse(arrow.rawValue.isEmpty)
            XCTAssertFalse(arrow.iconSymbol.isEmpty)
            
            let item = AnnotationItem.arrow(type: arrow, start: start, end: end, color: .systemRed, strokeWidth: 3)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let ctx = CGContext(data: nil, width: 100, height: 80, bitsPerComponent: 8, bytesPerRow: 400, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            item.draw(in: ctx)
            XCTAssertNotNil(ctx.makeImage())
        }
    }
    
    func testTransparentTextAnnotation() {
        let textItem = AnnotationItem.text(text: "Test Annotation", origin: CGPoint(x: 10, y: 10), font: NSFont.systemFont(ofSize: 14), color: .white)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 150, height: 50, bitsPerComponent: 8, bytesPerRow: 600, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        textItem.draw(in: ctx)
        XCTAssertNotNil(ctx.makeImage())
    }
    
    func testCopyToPasteboardIntegration() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 120, height: 100, bitsPerComponent: 8, bytesPerRow: 480, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.red.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 100))
        let cgImage = ctx.makeImage()!
        
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        
        // Execute copy to pasteboard
        ImageExporter.copyToPasteboard(cgImage: cgImage, screen: screen)
        
        let pasteboard = NSPasteboard.general
        
        // 1. Assert NSImage is readable and non-null
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
        let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage]
        XCTAssertNotNil(images)
        XCTAssertFalse(images?.isEmpty ?? true)
        
        // 2. Assert PNG data is present and non-empty
        let pngData = pasteboard.data(forType: .png)
        XCTAssertNotNil(pngData)
        XCTAssertGreaterThan(pngData?.count ?? 0, 50)
        
        // 3. Assert TIFF data is present and non-empty
        let tiffData = pasteboard.data(forType: .tiff)
        XCTAssertNotNil(tiffData)
        XCTAssertGreaterThan(tiffData?.count ?? 0, 50)
    }
}
