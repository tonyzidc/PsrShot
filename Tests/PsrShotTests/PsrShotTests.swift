import Testing
import Foundation
import CoreGraphics
import Cocoa
import Carbon
@testable import PsrShot

@Suite("PsrShot Core Tests")
struct PsrShotTests {
    
    @Test("Selection Handles Geometry and Positions")
    func testSelectionHandleRects() {
        let selection = CGRect(x: 100, y: 100, width: 200, height: 150)
        let handleSize = SelectionHandle.handleSize
        
        // Top Left
        let tl = SelectionHandle.topLeft.rect(for: selection)
        #expect(tl.origin.x == 100 - handleSize / 2)
        #expect(tl.origin.y == 100 - handleSize / 2)
        #expect(tl.width == handleSize)
        #expect(tl.height == handleSize)
        
        // Bottom Right
        let br = SelectionHandle.bottomRight.rect(for: selection)
        #expect(br.origin.x == 300 - handleSize / 2)
        #expect(br.origin.y == 250 - handleSize / 2)
        
        // Top Center
        let tc = SelectionHandle.topCenter.rect(for: selection)
        #expect(tc.origin.x == 200 - handleSize / 2)
        #expect(tc.origin.y == 100 - handleSize / 2)
    }
    
    @Test("Selection Handle Hit Testing")
    func testSelectionHandleHitTesting() {
        let selection = CGRect(x: 100, y: 100, width: 200, height: 150)
        
        // Point right at top-left
        let handleAtTL = SelectionHandle.handle(at: CGPoint(x: 100, y: 100), in: selection)
        #expect(handleAtTL == .topLeft)
        
        // Point right at bottom-right
        let handleAtBR = SelectionHandle.handle(at: CGPoint(x: 300, y: 250), in: selection)
        #expect(handleAtBR == .bottomRight)
        
        // Point in the dead center should NOT hit any handle
        let handleAtCenter = SelectionHandle.handle(at: CGPoint(x: 200, y: 175), in: selection)
        #expect(handleAtCenter == nil)
    }
    
    @Test("Selection Handle Resizing")
    func testSelectionHandleResizing() {
        let original = CGRect(x: 100, y: 100, width: 200, height: 150)
        
        // Drag bottom-right handle outwards to (350, 300)
        let updatedBR = SelectionHandle.bottomRight.updatedRect(original: original, currentPoint: CGPoint(x: 350, y: 300))
        #expect(updatedBR.origin.x == 100)
        #expect(updatedBR.origin.y == 100)
        #expect(updatedBR.width == 250)
        #expect(updatedBR.height == 200)
        
        // Drag top-left handle to (80, 70)
        let updatedTL = SelectionHandle.topLeft.updatedRect(original: original, currentPoint: CGPoint(x: 80, y: 70))
        #expect(updatedTL.origin.x == 80)
        #expect(updatedTL.origin.y == 70)
        #expect(updatedTL.maxX == 300)
        #expect(updatedTL.maxY == 250)
    }
    
    @Test("Image Export Formats and MIME Types")
    func testImageExportFormats() {
        #expect(ImageExportFormat.png.fileExtension == "png")
        #expect(ImageExportFormat.jpeg.fileExtension == "jpg")
        #expect(ImageExportFormat.webp.fileExtension == "webp")
        #expect(ImageExportFormat.heic.fileExtension == "heic")
        
        #expect(ImageExportFormat.png.mimeType == "image/png")
        #expect(ImageExportFormat.jpeg.mimeType == "image/jpeg")
        #expect(ImageExportFormat.webp.mimeType == "image/webp")
        #expect(ImageExportFormat.heic.mimeType == "image/heic")
    }
    
    @Test("Image Compression Settings Serialization")
    func testImageCompressionSettingsSerialization() throws {
        let settings = ImageCompressionSettings(
            format: .jpeg,
            isCompressionEnabled: true,
            quality: 0.75
        )
        
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ImageCompressionSettings.self, from: data)
        
        #expect(decoded.format == .jpeg)
        #expect(decoded.isCompressionEnabled == true)
        #expect(decoded.quality == 0.75)
    }
    
    @Test("S3 Configuration Validation and Serialization")
    func testS3Configuration() throws {
        var config = S3Config()
        #expect(config.isConfigured == false)
        
        config.bucket = "my-bucket"
        config.accessKeyId = "AKIA123"
        config.secretAccessKey = "SECRET456"
        #expect(config.isConfigured == true)
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(S3Config.self, from: data)
        #expect(decoded == config)
    }
    
    @Test("S3 SigV4 Signer Header Generation")
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
        
        #expect(headers["Authorization"]?.contains("AWS4-HMAC-SHA256") == true)
        #expect(headers["Authorization"]?.contains("Credential=TESTKEY") == true)
        #expect(headers["x-amz-content-sha256"] != nil)
        #expect(headers["x-amz-date"] != nil)
        #expect(headers["Content-Type"] == "image/png")
    }
    
    @Test("Hotkey Display String and Carbon Modifiers")
    func testHotkeyManagerHelpers() {
        let cmdShiftFlags: NSEvent.ModifierFlags = [.command, .shift]
        let carbonMods = HotkeyManager.carbonModifiers(from: cmdShiftFlags)
        #expect((carbonMods & UInt32(cmdKey)) != 0)
        #expect((carbonMods & UInt32(shiftKey)) != 0)
        #expect((carbonMods & UInt32(optionKey)) == 0)
        
        let display = HotkeyManager.displayString(keyCode: UInt32(kVK_ANSI_X), carbonModifiers: carbonMods)
        #expect(display == "⇧⌘X")
    }
    
    @Test("Image Exporter Offscreen Rendering")
    func testImageExporterRendering() {
        // Create 100x100 dummy bitmap
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: 200,
            height: 200,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let baseImage = ctx.makeImage()!
        
        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let crop = CGRect(x: 10, y: 10, width: 80, height: 60)
        
        let annotations: [AnnotationItem] = [
            .rectangle(rect: CGRect(x: 15, y: 15, width: 40, height: 30), color: .red, strokeWidth: 2, isFilled: false),
            .arrow(start: CGPoint(x: 20, y: 20), end: CGPoint(x: 60, y: 50), color: .blue, strokeWidth: 3)
        ]
        
        let rendered = ImageExporter.renderFinalImage(
            baseImage: baseImage,
            screen: screen,
            cropRect: crop,
            annotations: annotations
        )
        
        #expect(rendered != nil)
        if let rendered = rendered {
            let scale = screen.backingScaleFactor
            #expect(rendered.width == Int(80 * scale))
            #expect(rendered.height == Int(60 * scale))
        }
    }
}
