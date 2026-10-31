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
    public private(set) var currentTool: AnnotationTool = .select
    public private(set) var currentShape: ShapeType = .rectangle
    public private(set) var currentArrow: ArrowType = .single
    public private(set) var currentColor: NSColor = .systemRed
    public private(set) var currentStrokeWidth: CGFloat = 3.0
    
    // Tool buttons
    private var selectBtn: ToolButton!
    private var shapeBtn: ToolButton!
    private var arrowBtn: ToolButton!
    private var penBtn: ToolButton!
    private var textBtn: ToolButton!
    private var blurBtn: ToolButton!
    
    private var colorButtons: [(NSColor, ColorSwatchButton)] = []
    private var colorPickerBtn: ToolButton!
    
    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 630, height: 38))
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
        // Select Tool
        selectBtn = ToolButton(systemSymbol: "arrow.up.left.and.arrow.down.right", tooltip: "Select & Move Region", target: self, action: #selector(selectClicked))
        selectBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        selectBtn.isToolSelected = true
        addSubview(selectBtn)
        xOffset += btnSize + 2
        
        // Shape Tool (Rect, Rounded, Ellipse, Filled)
        shapeBtn = ToolButton(systemSymbol: currentShape.iconSymbol, tooltip: "Shapes (Click for options: Rect, Rounded, Circle, Fill)", target: self, action: #selector(shapeClicked))
        shapeBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(shapeBtn)
        xOffset += btnSize + 2
        
        // Arrow Tool (Single, Double, Line, Dashed)
        arrowBtn = ToolButton(systemSymbol: currentArrow.iconSymbol, tooltip: "Arrows (Click for options: Single, Double, Line, Dashed)", target: self, action: #selector(arrowClicked))
        arrowBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(arrowBtn)
        xOffset += btnSize + 2
        
        // Pen Tool
        penBtn = ToolButton(systemSymbol: "pencil.tip", tooltip: "Freehand Pen", target: self, action: #selector(penClicked))
        penBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(penBtn)
        xOffset += btnSize + 2
        
        // Text Tool
        textBtn = ToolButton(systemSymbol: "textformat", tooltip: "Insert Text (Transparent Background)", target: self, action: #selector(textClicked))
        textBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(textBtn)
        xOffset += btnSize + 2
        
        // Blur Tool
        blurBtn = ToolButton(systemSymbol: "eye.slash", tooltip: "Blur Sensitive Area", target: self, action: #selector(blurClicked))
        blurBtn.frame = NSRect(x: xOffset, y: btnY, width: btnSize, height: btnSize)
        addSubview(blurBtn)
        xOffset += btnSize + 2
        
        // Separator
        xOffset += 4
        addSubview(makeSeparator(at: xOffset))
        xOffset += 8
        
        // --- 2. Color Palette (8 vibrant presets + Native Color Picker) ---
        let colors: [(NSColor, String)] = [
            (.systemRed, "Red"),
            (.systemOrange, "Orange"),
            (.systemYellow, "Yellow"),
            (.systemGreen, "Green"),
            (.systemBlue, "Blue"),
            (.systemPurple, "Purple"),
            (.black, "Black"),
            (.white, "White")
        ]
        
        for (color, tip) in colors {
            let swatch = ColorSwatchButton(color: color, tooltip: tip, target: self, action: #selector(colorClicked(_:)))
            swatch.frame = NSRect(x: xOffset + 1, y: btnY + 3, width: 20, height: 20)
            if color == currentColor {
                swatch.isSwatchSelected = true
            }
            addSubview(swatch)
            colorButtons.append((color, swatch))
            xOffset += 22
        }
        
        // Native Color Picker Button (🎨)
        colorPickerBtn = ToolButton(systemSymbol: "paintpalette", tooltip: "Custom Colors & Eyedropper...", target: self, action: #selector(openColorPanel))
        colorPickerBtn.frame = NSRect(x: xOffset + 2, y: btnY, width: btnSize, height: btnSize)
        addSubview(colorPickerBtn)
        xOffset += btnSize + 6
        
        // Separator
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
    
    private func deselectAllTools() {
        selectBtn.isToolSelected = false
        shapeBtn.isToolSelected = false
        arrowBtn.isToolSelected = false
        penBtn.isToolSelected = false
        textBtn.isToolSelected = false
        blurBtn.isToolSelected = false
    }
    
    // MARK: - Tool Actions
    
    @objc private func selectClicked() {
        deselectAllTools()
        selectBtn.isToolSelected = true
        currentTool = .select
        onToolSelected?(.select)
    }
    
    @objc private func shapeClicked() {
        deselectAllTools()
        shapeBtn.isToolSelected = true
        currentTool = .shape(currentShape)
        onToolSelected?(currentTool)
        
        // Show shape menu on click
        showShapeMenu()
    }
    
    private func showShapeMenu() {
        let menu = NSMenu()
        for shape in ShapeType.allCases {
            let item = NSMenuItem(title: shape.rawValue, action: #selector(selectShapeVariant(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = shape
            if let img = NSImage(systemSymbolName: shape.iconSymbol, accessibilityDescription: shape.rawValue) {
                item.image = img
            }
            if shape == currentShape {
                item.state = .on
            }
            menu.addItem(item)
        }
        
        let point = NSPoint(x: shapeBtn.frame.minX, y: bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: self)
    }
    
    @objc private func selectShapeVariant(_ sender: NSMenuItem) {
        if let shape = sender.representedObject as? ShapeType {
            currentShape = shape
            if let img = NSImage(systemSymbolName: shape.iconSymbol, accessibilityDescription: shape.rawValue) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                shapeBtn.image = img.withSymbolConfiguration(config)
            }
            deselectAllTools()
            shapeBtn.isToolSelected = true
            currentTool = .shape(shape)
            onToolSelected?(currentTool)
        }
    }
    
    @objc private func arrowClicked() {
        deselectAllTools()
        arrowBtn.isToolSelected = true
        currentTool = .arrow(currentArrow)
        onToolSelected?(currentTool)
        
        showArrowMenu()
    }
    
    private func showArrowMenu() {
        let menu = NSMenu()
        for arrow in ArrowType.allCases {
            let item = NSMenuItem(title: arrow.rawValue, action: #selector(selectArrowVariant(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = arrow
            if let img = NSImage(systemSymbolName: arrow.iconSymbol, accessibilityDescription: arrow.rawValue) {
                item.image = img
            }
            if arrow == currentArrow {
                item.state = .on
            }
            menu.addItem(item)
        }
        
        let point = NSPoint(x: arrowBtn.frame.minX, y: bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: self)
    }
    
    @objc private func selectArrowVariant(_ sender: NSMenuItem) {
        if let arrow = sender.representedObject as? ArrowType {
            currentArrow = arrow
            if let img = NSImage(systemSymbolName: arrow.iconSymbol, accessibilityDescription: arrow.rawValue) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
                arrowBtn.image = img.withSymbolConfiguration(config)
            }
            deselectAllTools()
            arrowBtn.isToolSelected = true
            currentTool = .arrow(arrow)
            onToolSelected?(currentTool)
        }
    }
    
    @objc private func penClicked() {
        deselectAllTools()
        penBtn.isToolSelected = true
        currentTool = .pen
        onToolSelected?(.pen)
    }
    
    @objc private func textClicked() {
        deselectAllTools()
        textBtn.isToolSelected = true
        currentTool = .text
        onToolSelected?(.text)
    }
    
    @objc private func blurClicked() {
        deselectAllTools()
        blurBtn.isToolSelected = true
        currentTool = .blur
        onToolSelected?(.blur)
    }
    
    // MARK: - Color Palette & NSColorPanel
    
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
    
    @objc private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = currentColor
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelColorDidChange(_:)))
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func colorPanelColorDidChange(_ sender: NSColorPanel) {
        let newColor = sender.color
        self.currentColor = newColor
        
        // Deselect fixed preset swatches unless matches
        for (color, btn) in colorButtons {
            btn.isSwatchSelected = (color == newColor)
        }
        onColorSelected?(newColor)
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
