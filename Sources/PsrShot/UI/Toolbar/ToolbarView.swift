import Cocoa

public final class ToolbarView: NSVisualEffectView {
    // Action Callbacks
    public var onToolSelected: ((AnnotationTool) -> Void)?
    public var onColorSelected: ((NSColor) -> Void)?
    public var onStrokeWidthSelected: ((CGFloat) -> Void)?
    public var onUndo: (() -> Void)?
    public var onCopy: (() -> Void)?
    public var onSave: (() -> Void)?
    public var onUpload: (() -> Void)?
    public var onClose: (() -> Void)?
    
    // State
    private var currentTool: AnnotationTool = .select
    private var currentColor: NSColor = .systemRed
    private var currentStrokeWidth: CGFloat = 3.0
    
    // Tool buttons
    private var toolButtons: [AnnotationTool: ToolButton] = [:]
    private var colorButtons: [(NSColor, ColorSwatchButton)] = []
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 490, height: 38))
        setupHUD()
        buildControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupHUD() {
        self.material = .hudWindow
        self.state = .active
        self.blendingMode = .withinWindow
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.layer?.masksToBounds = true
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        self.layer?.borderWidth = 1.0
        self.shadow = NSShadow()
        self.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.4)
        self.shadow?.shadowBlurRadius = 8
        self.shadow?.shadowOffset = NSSize(width: 0, height: -2)
    }
    
    private func buildControls() {
        var xOffset: CGFloat = 8
        let btnY: CGFloat = 5
        let btnSize: CGFloat = 28
        
        // --- 1. Tools Group ---
        let tools: [(AnnotationTool, String, String)] = [
            (.select, "arrow.up.left.and.arrow.down.right", "Select & Move Region"),
            (.rectangle(filled: false), "square", "Draw Rectangle"),
            (.arrow, "arrow.up.right", "Draw Arrow"),
            (.pen, "pencil.tip", "Freehand Pen"),
            (.text, "textformat", "Insert Text"),
            (.blur, "eye.slash", "Blur Sensitive Area")
        ]
        
        for (tool, symbol, tip) in tools {
            let btn = ToolButton(systemSymbol: symbol, tooltip: tip, target: self, action: #selector(toolClicked(_:)))
            btn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
            addSubview(btn)
            toolButtons[tool] = btn
            xOffset += btnSize + 2
        }
        toolButtons[.select]?.isToolSelected = true
        
        // Separator
        xOffset += 4
        addSubview(makeSeparator(at: xOffset))
        xOffset += 8
        
        // --- 2. Color Palette ---
        let colors: [(NSColor, String)] = [
            (.systemRed, "Red Color"),
            (.systemBlue, "Blue Color"),
            (.systemGreen, "Green Color"),
            (.systemYellow, "Yellow Color"),
            (.white, "White Color")
        ]
        
        for (color, tip) in colors {
            let swatch = ColorSwatchButton(color: color, tooltip: tip, target: self, action: #selector(colorClicked(_:)))
            swatch.frame = NSRect(x: xOffset + 2, y: btnY + 3, width: 22, height: 22)
            if color == currentColor {
                swatch.isSwatchSelected = true
            }
            addSubview(swatch)
            colorButtons.append((color, swatch))
            xOffset += 24
        }
        
        // Separator
        xOffset += 4
        addSubview(makeSeparator(at: xOffset))
        xOffset += 8
        
        // --- 3. Undo ---
        let undoBtn = ToolButton(systemSymbol: "arrow.uturn.backward", tooltip: "Undo (Cmd + Z)", target: self, action: #selector(undoClicked))
        undoBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(undoBtn)
        xOffset += btnSize + 6
        
        // Separator
        addSubview(makeSeparator(at: xOffset))
        xOffset += 8
        
        // --- 4. Actions: Copy, Save, Upload, Close ---
        let copyBtn = ToolButton(systemSymbol: "doc.on.clipboard", tooltip: "Copy to Clipboard (Cmd + C)", target: self, action: #selector(copyClicked))
        copyBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(copyBtn)
        xOffset += btnSize + 2
        
        let saveBtn = ToolButton(systemSymbol: "square.and.arrow.down", tooltip: "Save to Disk (Cmd + S)", target: self, action: #selector(saveClicked))
        saveBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(saveBtn)
        xOffset += btnSize + 2
        
        let uploadBtn = ToolButton(systemSymbol: "icloud.and.arrow.up", tooltip: "Upload to S3 Cloud & Copy Link (Cmd + U)", target: self, action: #selector(uploadClicked))
        uploadBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(uploadBtn)
        xOffset += btnSize + 2
        
        let closeBtn = ToolButton(systemSymbol: "xmark", tooltip: "Close (ESC)", target: self, action: #selector(closeClicked))
        closeBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(closeBtn)
        xOffset += btnSize + 8
        
        // Update frame width to fit controls neatly
        self.frame.size.width = xOffset
    }
    
    private func makeSeparator(at x: CGFloat) -> NSView {
        let sep = NSView(frame: NSRect(x: x, y: 7, width: 1, height: 24))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        return sep
    }
    
    // MARK: - Actions
    
    @objc private func toolClicked(_ sender: ToolButton) {
        for (tool, btn) in toolButtons {
            if btn === sender {
                btn.isToolSelected = true
                currentTool = tool
                onToolSelected?(tool)
            } else {
                btn.isToolSelected = false
            }
        }
    }
    
    @objc private func colorClicked(_ sender: ColorSwatchButton) {
        for (color, btn) in colorButtons {
            if btn === sender {
                btn.isSwatchSelected = true
                currentColor = color
                onColorSelected?(color)
            } else {
                btn.isSwatchSelected = false
            }
        }
    }
    
    @objc private func undoClicked() {
        onUndo?()
    }
    
    @objc private func copyClicked() {
        onCopy?()
    }
    
    @objc private func saveClicked() {
        onSave?()
    }
    
    @objc private func uploadClicked() {
        onUpload?()
    }
    
    @objc private func closeClicked() {
        onClose?()
    }
    
    // MARK: - Positioning Helper
    
    public func updatePosition(anchoredTo selection: CGRect, in bounds: CGRect) {
        let margin: CGFloat = 8
        var targetX = selection.maxX - self.frame.width
        var targetY = selection.maxY + margin
        
        // If bottom overflows, place above selection
        if targetY + self.frame.height > bounds.maxY {
            targetY = selection.minY - self.frame.height - margin
        }
        
        // Clamp X within screen bounds
        if targetX < bounds.minX + margin {
            targetX = bounds.minX + margin
        }
        if targetX + self.frame.width > bounds.maxX - margin {
            targetX = bounds.maxX - self.frame.width - margin
        }
        
        // Clamp Y within screen bounds
        if targetY < bounds.minY + margin {
            targetY = bounds.minY + margin
        }
        
        self.frame.origin = CGPoint(x: targetX, y: targetY)
    }
}
