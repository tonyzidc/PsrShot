import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no Dock icon, menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        setupHotkey()
        NotificationManager.shared.requestAuthorization()
    }
    
    // MARK: - Menu Bar Status Item
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "PsrShot") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                button.image = img.withSymbolConfiguration(config)
            } else {
                button.title = "📸"
            }
            button.toolTip = "PsrShot - Screen Capture"
        }
        
        let menu = NSMenu()
        
        let captureItem = NSMenuItem(title: "Capture Area", action: #selector(captureAreaClicked), keyEquivalent: "")
        menu.addItem(captureItem)
        
        let captureFullScreenItem = NSMenuItem(title: "Capture Fullscreen", action: #selector(captureFullScreenClicked), keyEquivalent: "")
        menu.addItem(captureFullScreenItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferencesClicked), keyEquivalent: ",")
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About PsrShot", action: #selector(aboutClicked), keyEquivalent: "")
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Quit PsrShot", action: #selector(quitClicked), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Hotkey
    
    private func setupHotkey() {
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.triggerCapture()
        }
        HotkeyManager.shared.registerDefaultOrSaved()
    }
    
    // MARK: - Capture Flow
    
    @objc public func triggerCapture() {
        PermissionsManager.shared.promptForScreenRecordingPermissionIfNeeded { granted in
            guard granted else { return }
            
            CaptureManager.shared.captureActiveDisplay { result in
                switch result {
                case .success(let (image, screen)):
                    OverlayWindowController.shared.showOverlay(image: image, screen: screen)
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "Screen Capture Error"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
    
    @objc private func captureAreaClicked() {
        triggerCapture()
    }
    
    @objc private func captureFullScreenClicked() {
        PermissionsManager.shared.promptForScreenRecordingPermissionIfNeeded { granted in
            guard granted else { return }
            CaptureManager.shared.captureActiveDisplay { result in
                switch result {
                case .success(let (image, screen)):
                    ImageExporter.copyToPasteboard(cgImage: image, screen: screen)
                    NSSound.beep()
                    
                    let config = S3Config.load()
                    if config.autoUpload && config.isConfigured {
                        let settings = ImageCompressionSettings.load()
                        if let data = ImageExporter.encode(cgImage: image, settings: settings) {
                            S3Uploader.shared.upload(
                                imageData: data,
                                mimeType: settings.format.mimeType,
                                fileExtension: settings.format.fileExtension
                            ) { _ in }
                        }
                    }
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "Fullscreen Capture Error"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
    
    @objc private func openPreferencesClicked() {
        PreferencesWindowController.shared.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func aboutClicked() {
        let alert = NSAlert()
        alert.messageText = "PsrShot v1.0.0"
        alert.informativeText = "Ultra-lightweight native macOS screenshot & annotation tool (Lightshot Clone).\n\nFeatures:\n• Global customizable hotkey\n• Rich annotation suite (Rectangle, Arrow, Pen, Text, Blur)\n• Multi-format export (PNG, JPEG, WebP, HEIC) with hardware compression\n• Direct S3 / Cloudflare R2 / MinIO upload & clipboard view link\n\nBuilt natively with Swift, AppKit, and zero external dependencies."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
