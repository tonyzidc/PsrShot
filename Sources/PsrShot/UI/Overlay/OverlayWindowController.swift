import Cocoa

public final class OverlayWindowController: NSWindowController {
    public static let shared = OverlayWindowController()
    
    private var overlayPanel: OverlayPanel?
    private var canvasView: CanvasView?
    private var capturedImage: CGImage?
    private var capturedScreen: NSScreen?
    
    private init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func showOverlay(image: CGImage, screen: NSScreen) {
        dismiss() // ensure any previous overlay is torn down
        
        self.capturedImage = image
        self.capturedScreen = screen
        
        let screenFrame = screen.frame
        let panel = OverlayPanel(contentRect: screenFrame)
        panel.setFrame(screenFrame, display: true)
        
        let canvas = CanvasView(frame: NSRect(origin: .zero, size: screenFrame.size))
        canvas.baseImage = image
        canvas.targetScreen = screen
        
        canvas.onDismissRequested = { [weak self] in
            self?.dismiss()
        }
        
        canvas.onCopyRequested = { [weak self] in
            self?.handleCopy()
        }
        
        canvas.onSaveRequested = { [weak self] in
            self?.handleSave()
        }
        
        canvas.onUploadRequested = { [weak self] in
            self?.handleUpload()
        }
        
        panel.contentView = canvas
        self.overlayPanel = panel
        self.canvasView = canvas
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(canvas)
    }
    
    public func dismiss() {
        if let panel = overlayPanel {
            panel.orderOut(nil)
            panel.contentView = nil
            self.overlayPanel = nil
        }
        canvasView = nil
        capturedImage = nil
        capturedScreen = nil
    }
    
    // MARK: - Actions
    
    private func handleCopy() {
        guard let base = capturedImage,
              let screen = capturedScreen,
              let canvas = canvasView,
              !canvas.selectionRect.isEmpty,
              let finalImage = ImageExporter.renderFinalImage(
                baseImage: base,
                screen: screen,
                cropRect: canvas.selectionRect,
                annotations: canvas.annotations
              ) else { return }
        
        ImageExporter.copyToPasteboard(cgImage: finalImage)
        NSSound.beep() // subtle audio confirmation
        dismiss()
    }
    
    private func handleSave() {
        guard let base = capturedImage,
              let screen = capturedScreen,
              let canvas = canvasView,
              !canvas.selectionRect.isEmpty,
              let finalImage = ImageExporter.renderFinalImage(
                baseImage: base,
                screen: screen,
                cropRect: canvas.selectionRect,
                annotations: canvas.annotations
              ) else { return }
        
        let settings = ImageCompressionSettings.load()
        
        // Hide overlay momentarily so save sheet / modal isn't blocked by screenSaver level
        overlayPanel?.orderOut(nil)
        
        ImageExporter.saveToDisk(cgImage: finalImage, settings: settings, parentWindow: nil) { [weak self] success in
            self?.dismiss()
        }
    }
    
    private func handleUpload() {
        guard let base = capturedImage,
              let screen = capturedScreen,
              let canvas = canvasView,
              !canvas.selectionRect.isEmpty,
              let finalImage = ImageExporter.renderFinalImage(
                baseImage: base,
                screen: screen,
                cropRect: canvas.selectionRect,
                annotations: canvas.annotations
              ) else { return }
        
        let settings = ImageCompressionSettings.load()
        guard let data = ImageExporter.encode(cgImage: finalImage, settings: settings) else {
            dismiss()
            return
        }
        
        // Dismiss immediately so user is back to their desktop while upload completes in background
        dismiss()
        
        S3Uploader.shared.upload(
            imageData: data,
            mimeType: settings.format.mimeType,
            fileExtension: settings.format.fileExtension
        ) { result in
            switch result {
            case .success(let viewURL):
                NSLog("[PsrShot] Uploaded successfully: \(viewURL)")
            case .failure(let error):
                NSLog("[PsrShot] Upload failed: \(error)")
            }
        }
    }
}
