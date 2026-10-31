import Cocoa
import Carbon

public final class PreferencesWindowController: NSWindowController {
    public static let shared = PreferencesWindowController()
    
    // Tab View
    private var tabView: NSTabView!
    
    // UI Elements for Format & Compression
    private var formatPopup = NSPopUpButton()
    private var compressionCheckbox = NSButton(checkboxWithTitle: "Enable image compression (Lossy Compression)", target: nil, action: nil)
    private var qualitySlider = NSSlider(value: 80, minValue: 10, maxValue: 100, target: nil, action: nil)
    private var qualityLabel = NSTextField(labelWithString: "80%")
    
    // UI Elements for Updates
    private var autoCheckUpdatesCheckbox = NSButton(checkboxWithTitle: "Automatically check for updates on startup", target: nil, action: nil)
    
    // UI Elements for S3
    private var endpointField = NSTextField()
    private var regionField = NSTextField()
    private var bucketField = NSTextField()
    private var accessKeyField = NSTextField()
    private var secretKeyField = NSSecureTextField()
    private var publicURLField = NSTextField()
    private var prefixField = NSTextField()
    private var autoUploadCheckbox = NSButton(checkboxWithTitle: "Auto-upload to S3 after screen capture", target: nil, action: nil)
    private var s3StatusLabel = NSTextField(labelWithString: "")
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 490, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PsrShot Preferences"
        window.center()
        super.init(window: window)
        
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        tabView = NSTabView(frame: window.contentView?.bounds.insetBy(dx: 12, dy: 12) ?? .zero)
        tabView.autoresizingMask = [.width, .height]
        
        // Tab 1: General & Hotkeys
        let tab1 = NSTabViewItem(identifier: "general")
        tab1.label = "Hotkeys"
        tab1.view = buildGeneralTab()
        tabView.addTabViewItem(tab1)
        
        // Tab 2: Format & Compression
        let tab2 = NSTabViewItem(identifier: "format")
        tab2.label = "Format & Compression"
        tab2.view = buildFormatTab()
        tabView.addTabViewItem(tab2)
        
        // Tab 3: S3 Cloud Storage
        let tab3 = NSTabViewItem(identifier: "s3")
        tab3.label = "S3 Cloud Storage"
        tab3.view = buildS3Tab()
        tabView.addTabViewItem(tab3)
        
        window.contentView?.addSubview(tabView)
    }
    
    public func selectTab(identifier: String) {
        tabView.selectTabViewItem(withIdentifier: identifier)
    }
    
    // MARK: - Tab 1: General & Hotkey
    
    private func buildGeneralTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 350))
        
        let hotkeyTitle = NSTextField(labelWithString: "Global screen capture hotkey:")
        hotkeyTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        hotkeyTitle.frame = NSRect(x: 20, y: 290, width: 400, height: 20)
        view.addSubview(hotkeyTitle)
        
        let recorder = ShortcutRecorderView(frame: NSRect(x: 20, y: 246, width: 220, height: 34))
        view.addSubview(recorder)
        
        let hint = NSTextField(labelWithString: "Click the box above and press your shortcut (e.g. ⌥A, ⌘⇧4, ⌘⇧X).")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 216, width: 420, height: 20)
        view.addSubview(hint)
        
        let resetBtn = NSButton(title: "Reset to Default (⌘⇧X)", target: self, action: #selector(resetDefaultHotkey))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 16, y: 170, width: 228, height: 32)
        view.addSubview(resetBtn)
        
        let separator = NSBox(frame: NSRect(x: 20, y: 145, width: 420, height: 1))
        separator.boxType = .separator
        view.addSubview(separator)
        
        let updatesTitle = NSTextField(labelWithString: "Software Updates:")
        updatesTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        updatesTitle.frame = NSRect(x: 20, y: 112, width: 400, height: 20)
        view.addSubview(updatesTitle)
        
        autoCheckUpdatesCheckbox.frame = NSRect(x: 20, y: 82, width: 380, height: 22)
        autoCheckUpdatesCheckbox.state = UpdateChecker.shared.autoCheckOnLaunch ? .on : .off
        autoCheckUpdatesCheckbox.target = self
        autoCheckUpdatesCheckbox.action = #selector(autoCheckUpdatesChanged)
        view.addSubview(autoCheckUpdatesCheckbox)
        
        let checkNowBtn = NSButton(title: "Check for Updates Now...", target: self, action: #selector(checkUpdatesFromPrefsClicked))
        checkNowBtn.bezelStyle = .rounded
        checkNowBtn.frame = NSRect(x: 16, y: 40, width: 200, height: 32)
        view.addSubview(checkNowBtn)
        
        return view
    }
    
    @objc private func autoCheckUpdatesChanged() {
        UpdateChecker.shared.autoCheckOnLaunch = (autoCheckUpdatesCheckbox.state == .on)
    }
    
    @objc private func checkUpdatesFromPrefsClicked() {
        AboutWindowController.shared.showWindow(nil)
        AboutWindowController.shared.checkUpdatesClicked()
    }
    
    @objc private func resetDefaultHotkey() {
        let code = UInt32(kVK_ANSI_X)
        let mods = UInt32(cmdKey | shiftKey)
        HotkeyManager.shared.register(keyCode: code, carbonModifiers: mods)
        // Refresh recorder
        if let tab1 = tabView.tabViewItem(at: 0).view {
            for v in tab1.subviews {
                if let rec = v as? ShortcutRecorderView {
                    rec.setShortcut(keyCode: code, carbonModifiers: mods)
                }
            }
        }
    }
    
    // MARK: - Tab 2: Format & Compression
    
    private func buildFormatTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 350))
        let settings = ImageCompressionSettings.load()
        
        // Format selector
        let formatLabel = NSTextField(labelWithString: "Export image format:")
        formatLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        formatLabel.frame = NSRect(x: 20, y: 290, width: 200, height: 20)
        view.addSubview(formatLabel)
        
        formatPopup.frame = NSRect(x: 20, y: 256, width: 180, height: 28)
        formatPopup.removeAllItems()
        for format in ImageExportFormat.allCases {
            formatPopup.addItem(withTitle: format.rawValue)
        }
        formatPopup.selectItem(withTitle: settings.format.rawValue)
        formatPopup.target = self
        formatPopup.action = #selector(formatOrCompressionChanged)
        view.addSubview(formatPopup)
        
        // Compression Checkbox
        compressionCheckbox.frame = NSRect(x: 20, y: 206, width: 400, height: 24)
        compressionCheckbox.state = settings.isCompressionEnabled ? .on : .off
        compressionCheckbox.target = self
        compressionCheckbox.action = #selector(formatOrCompressionChanged)
        view.addSubview(compressionCheckbox)
        
        // Quality Slider
        let sliderLabel = NSTextField(labelWithString: "Compression quality:")
        sliderLabel.font = NSFont.systemFont(ofSize: 12)
        sliderLabel.frame = NSRect(x: 20, y: 166, width: 200, height: 20)
        view.addSubview(sliderLabel)
        
        qualitySlider.frame = NSRect(x: 20, y: 136, width: 280, height: 24)
        qualitySlider.doubleValue = Double(settings.quality * 100)
        qualitySlider.target = self
        qualitySlider.action = #selector(sliderMoved(_:))
        view.addSubview(qualitySlider)
        
        qualityLabel.frame = NSRect(x: 310, y: 136, width: 60, height: 24)
        qualityLabel.stringValue = "\(Int(settings.quality * 100))%"
        qualityLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        view.addSubview(qualityLabel)
        
        let note = NSTextField(labelWithString: "Note: Compression applies to JPEG, WebP, and HEIC when saving to disk and uploading to S3.\nSignificantly reduces file size while preserving sharp text.")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 20, y: 65, width: 420, height: 40)
        view.addSubview(note)
        
        return view
    }
    
    @objc private func sliderMoved(_ sender: NSSlider) {
        let val = Int(sender.doubleValue)
        qualityLabel.stringValue = "\(val)%"
        formatOrCompressionChanged()
    }
    
    @objc private func formatOrCompressionChanged() {
        let formatStr = formatPopup.titleOfSelectedItem ?? "PNG"
        let format = ImageExportFormat(rawValue: formatStr) ?? .png
        let isEnabled = (compressionCheckbox.state == .on)
        let quality = Float(qualitySlider.doubleValue) / 100.0
        
        let settings = ImageCompressionSettings(
            format: format,
            isCompressionEnabled: isEnabled,
            quality: quality
        )
        settings.save()
    }
    
    // MARK: - Tab 3: S3 Storage
    
    private func buildS3Tab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 350))
        let config = S3Config.load()
        
        var y: CGFloat = 300
        let h: CGFloat = 22
        let gap: CGFloat = 30
        
        func addRow(label: String, field: NSTextField, placeholder: String) {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: 10, y: y, width: 140, height: h)
            lbl.alignment = .right
            lbl.font = NSFont.systemFont(ofSize: 12)
            view.addSubview(lbl)
            
            field.frame = NSRect(x: 156, y: y, width: 270, height: h)
            field.placeholderString = placeholder
            view.addSubview(field)
            y -= gap
        }
        
        endpointField.stringValue = config.endpoint
        addRow(label: "Endpoint URL:", field: endpointField, placeholder: "Leave empty for AWS S3")
        
        regionField.stringValue = config.region
        addRow(label: "Region:", field: regionField, placeholder: "us-east-1 or auto")
        
        bucketField.stringValue = config.bucket
        addRow(label: "Bucket Name:", field: bucketField, placeholder: "my-screenshot-bucket")
        
        accessKeyField.stringValue = config.accessKeyId
        addRow(label: "Access Key ID:", field: accessKeyField, placeholder: "AKIA...")
        
        secretKeyField.stringValue = config.secretAccessKey
        addRow(label: "Secret Key:", field: secretKeyField, placeholder: "Secret Access Key")
        
        publicURLField.stringValue = config.publicBaseURL
        addRow(label: "Public Domain / CDN:", field: publicURLField, placeholder: "https://cdn.domain.com")
        
        prefixField.stringValue = config.pathPrefix
        addRow(label: "Folder Prefix:", field: prefixField, placeholder: "screenshots/")
        
        autoUploadCheckbox.frame = NSRect(x: 156, y: y + 4, width: 270, height: 20)
        autoUploadCheckbox.state = config.autoUpload ? .on : .off
        view.addSubview(autoUploadCheckbox)
        y -= 28
        
        // Action Buttons
        let testBtn = NSButton(title: "Test Connection", target: self, action: #selector(testS3Connection))
        testBtn.bezelStyle = .rounded
        testBtn.frame = NSRect(x: 150, y: y - 4, width: 130, height: 28)
        view.addSubview(testBtn)
        
        let saveBtn = NSButton(title: "Save Config", target: self, action: #selector(saveS3Config))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 286, y: y - 4, width: 130, height: 28)
        view.addSubview(saveBtn)
        
        s3StatusLabel.frame = NSRect(x: 20, y: y - 32, width: 410, height: 20)
        s3StatusLabel.font = NSFont.systemFont(ofSize: 11)
        s3StatusLabel.alignment = .center
        view.addSubview(s3StatusLabel)
        
        return view
    }
    
    private func currentConfigFromUI() -> S3Config {
        return S3Config(
            endpoint: endpointField.stringValue,
            region: regionField.stringValue.isEmpty ? "us-east-1" : regionField.stringValue,
            bucket: bucketField.stringValue,
            accessKeyId: accessKeyField.stringValue,
            secretAccessKey: secretKeyField.stringValue,
            publicBaseURL: publicURLField.stringValue,
            pathPrefix: prefixField.stringValue,
            autoUpload: autoUploadCheckbox.state == .on
        )
    }
    
    @objc private func testS3Connection() {
        s3StatusLabel.stringValue = "Testing connection..."
        s3StatusLabel.textColor = .labelColor
        let config = currentConfigFromUI()
        
        S3Uploader.shared.testConnection(config: config) { [weak self] result in
            switch result {
            case .success(let msg):
                self?.s3StatusLabel.stringValue = "✅ \(msg)"
                self?.s3StatusLabel.textColor = .systemGreen
            case .failure(let err):
                self?.s3StatusLabel.stringValue = "❌ \(err.localizedDescription)"
                self?.s3StatusLabel.textColor = .systemRed
            }
        }
    }
    
    @objc private func saveS3Config() {
        let config = currentConfigFromUI()
        config.save()
        s3StatusLabel.stringValue = "S3 configuration saved successfully!"
        s3StatusLabel.textColor = .systemGreen
    }
}
