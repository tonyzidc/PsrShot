import Cocoa
import Carbon

public final class PreferencesWindowController: NSWindowController {
    public static let shared = PreferencesWindowController()
    
    // UI Elements for Format & Compression
    private var formatPopup = NSPopUpButton()
    private var compressionCheckbox = NSButton(checkboxWithTitle: "Bật cơ chế nén ảnh (Lossy Compression)", target: nil, action: nil)
    private var qualitySlider = NSSlider(value: 80, minValue: 10, maxValue: 100, target: nil, action: nil)
    private var qualityLabel = NSTextField(labelWithString: "80%")
    
    // UI Elements for S3
    private var endpointField = NSTextField()
    private var regionField = NSTextField()
    private var bucketField = NSTextField()
    private var accessKeyField = NSTextField()
    private var secretKeyField = NSSecureTextField()
    private var publicURLField = NSTextField()
    private var prefixField = NSTextField()
    private var autoUploadCheckbox = NSButton(checkboxWithTitle: "Tự động tải lên S3 sau khi chụp màn hình", target: nil, action: nil)
    private var s3StatusLabel = NSTextField(labelWithString: "")
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cài đặt PsrShot"
        window.center()
        super.init(window: window)
        
        setupContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let tabView = NSTabView(frame: window.contentView?.bounds.insetBy(dx: 12, dy: 12) ?? .zero)
        tabView.autoresizingMask = [.width, .height]
        
        // Tab 1: General & Hotkeys
        let tab1 = NSTabViewItem(identifier: "general")
        tab1.label = "Phím tắt"
        tab1.view = buildGeneralTab()
        tabView.addTabViewItem(tab1)
        
        // Tab 2: Format & Compression
        let tab2 = NSTabViewItem(identifier: "format")
        tab2.label = "Định dạng & Nén"
        tab2.view = buildFormatTab()
        tabView.addTabViewItem(tab2)
        
        // Tab 3: S3 Cloud Storage
        let tab3 = NSTabViewItem(identifier: "s3")
        tab3.label = "S3 Cloud Storage"
        tab3.view = buildS3Tab()
        tabView.addTabViewItem(tab3)
        
        window.contentView?.addSubview(tabView)
    }
    
    // MARK: - Tab 1: General & Hotkey
    
    private func buildGeneralTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 340))
        
        let hotkeyTitle = NSTextField(labelWithString: "Phím tắt chụp màn hình toàn hệ thống:")
        hotkeyTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        hotkeyTitle.frame = NSRect(x: 20, y: 280, width: 400, height: 20)
        view.addSubview(hotkeyTitle)
        
        let recorder = ShortcutRecorderView(frame: NSRect(x: 20, y: 236, width: 220, height: 34))
        view.addSubview(recorder)
        
        let hint = NSTextField(labelWithString: "Bấm vào ô trên rồi nhấn tổ hợp phím mong muốn (ví dụ: ⌥A, ⌘⇧4, ⌘⇧X).")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 206, width: 400, height: 20)
        view.addSubview(hint)
        
        let resetBtn = NSButton(title: "Khôi phục mặc định (⌘⇧X)", target: self, action: #selector(resetDefaultHotkey))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 16, y: 160, width: 228, height: 32)
        view.addSubview(resetBtn)
        
        return view
    }
    
    @objc private func resetDefaultHotkey() {
        let code = UInt32(kVK_ANSI_X)
        let mods = UInt32(cmdKey | shiftKey)
        HotkeyManager.shared.register(keyCode: code, carbonModifiers: mods)
        // Refresh recorder
        if let window = window {
            for sub in window.contentView?.subviews ?? [] {
                if let tabView = sub as? NSTabView,
                   let tab1 = tabView.tabViewItem(at: 0).view {
                    for v in tab1.subviews {
                        if let rec = v as? ShortcutRecorderView {
                            rec.setShortcut(keyCode: code, carbonModifiers: mods)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Tab 2: Format & Compression
    
    private func buildFormatTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 340))
        let settings = ImageCompressionSettings.load()
        
        // Format selector
        let formatLabel = NSTextField(labelWithString: "Định dạng file xuất ra:")
        formatLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        formatLabel.frame = NSRect(x: 20, y: 280, width: 200, height: 20)
        view.addSubview(formatLabel)
        
        formatPopup.frame = NSRect(x: 20, y: 246, width: 180, height: 28)
        formatPopup.removeAllItems()
        for format in ImageExportFormat.allCases {
            formatPopup.addItem(withTitle: format.rawValue)
        }
        formatPopup.selectItem(withTitle: settings.format.rawValue)
        formatPopup.target = self
        formatPopup.action = #selector(formatOrCompressionChanged)
        view.addSubview(formatPopup)
        
        // Compression Checkbox
        compressionCheckbox.frame = NSRect(x: 20, y: 196, width: 380, height: 24)
        compressionCheckbox.state = settings.isCompressionEnabled ? .on : .off
        compressionCheckbox.target = self
        compressionCheckbox.action = #selector(formatOrCompressionChanged)
        view.addSubview(compressionCheckbox)
        
        // Quality Slider
        let sliderLabel = NSTextField(labelWithString: "Mức chất lượng ảnh (Quality):")
        sliderLabel.font = NSFont.systemFont(ofSize: 12)
        sliderLabel.frame = NSRect(x: 20, y: 156, width: 200, height: 20)
        view.addSubview(sliderLabel)
        
        qualitySlider.frame = NSRect(x: 20, y: 126, width: 280, height: 24)
        qualitySlider.doubleValue = Double(settings.quality * 100)
        qualitySlider.target = self
        qualitySlider.action = #selector(sliderMoved(_:))
        view.addSubview(qualitySlider)
        
        qualityLabel.frame = NSRect(x: 310, y: 126, width: 60, height: 24)
        qualityLabel.stringValue = "\(Int(settings.quality * 100))%"
        qualityLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        view.addSubview(qualityLabel)
        
        let note = NSTextField(labelWithString: "Lưu ý: Nén ảnh áp dụng cho JPEG, WebP, HEIC khi lưu vào ổ đĩa và tải lên S3.\nGiúp giảm kích thước file đáng kể mà vẫn giữ chữ viết sắc nét.")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 20, y: 60, width: 400, height: 40)
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
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 340))
        let config = S3Config.load()
        
        var y: CGFloat = 290
        let h: CGFloat = 22
        let gap: CGFloat = 32
        
        func addRow(label: String, field: NSTextField, placeholder: String) {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: 10, y: y, width: 140, height: h)
            lbl.alignment = .right
            lbl.font = NSFont.systemFont(ofSize: 12)
            view.addSubview(lbl)
            
            field.frame = NSRect(x: 156, y: y, width: 260, height: h)
            field.placeholderString = placeholder
            view.addSubview(field)
            y -= gap
        }
        
        endpointField.stringValue = config.endpoint
        addRow(label: "Endpoint URL:", field: endpointField, placeholder: "Để trống nếu dùng AWS S3")
        
        regionField.stringValue = config.region
        addRow(label: "Region:", field: regionField, placeholder: "us-east-1 hoặc auto")
        
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
        
        autoUploadCheckbox.frame = NSRect(x: 156, y: y + 4, width: 260, height: 20)
        autoUploadCheckbox.state = config.autoUpload ? .on : .off
        view.addSubview(autoUploadCheckbox)
        y -= 28
        
        // Action Buttons
        let testBtn = NSButton(title: "Kiểm tra kết nối", target: self, action: #selector(testS3Connection))
        testBtn.bezelStyle = .rounded
        testBtn.frame = NSRect(x: 150, y: y - 4, width: 130, height: 28)
        view.addSubview(testBtn)
        
        let saveBtn = NSButton(title: "Lưu cấu hình", target: self, action: #selector(saveS3Config))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.frame = NSRect(x: 286, y: y - 4, width: 130, height: 28)
        view.addSubview(saveBtn)
        
        s3StatusLabel.frame = NSRect(x: 20, y: y - 32, width: 396, height: 20)
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
        s3StatusLabel.stringValue = "Đang kiểm tra kết nối..."
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
        s3StatusLabel.stringValue = "Đã lưu cấu hình S3 thành công!"
        s3StatusLabel.textColor = .systemGreen
    }
}
