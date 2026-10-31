import Cocoa
import CoreGraphics

public final class CanvasView: NSView, NSTextFieldDelegate {
    
    // MARK: - Properties
    
    public override var isFlipped: Bool { return true }
    
    public var baseImage: CGImage? {
        didSet {
            needsDisplay = true
        }
    }
    public var targetScreen: NSScreen?
    
    // Selection state
    public var selectionRect: CGRect = .zero {
        didSet {
            updateToolbarVisibilityAndPosition()
            needsDisplay = true
        }
    }
    
    // Annotations
    public private(set) var annotations: [AnnotationItem] = []
    private var currentDrawingItem: AnnotationItem?
    
    // Active tool & appearance
    public var currentTool: AnnotationTool = .select
    public var currentColor: NSColor = .systemRed
    public var currentStrokeWidth: CGFloat = 3.0
    
    // Interaction state
    private enum MouseState {
        case idle
        case creatingSelection(start: CGPoint)
        case resizing(handle: SelectionHandle, initial: CGRect)
        case moving(startPoint: CGPoint, initialRect: CGRect)
        case drawing(tool: AnnotationTool, startPoint: CGPoint)
    }
    private var mouseState: MouseState = .idle
    
    // Inline text editing
    private var activeTextField: NSTextField?
    
    // UI Elements
    private let toolbar = ToolbarView()
    private var trackingArea: NSTrackingArea?
    
    // Callbacks to Window Controller
    public var onDismissRequested: (() -> Void)?
    public var onCopyRequested: (() -> Void)?
    public var onSaveRequested: (() -> Void)?
    public var onUploadRequested: (() -> Void)?
    
    // MARK: - Init
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        addSubview(toolbar)
        toolbar.isHidden = true
        
        setupToolbarActions()
    }
    
    private func setupToolbarActions() {
        toolbar.onToolSelected = { [weak self] tool in
            self?.commitActiveTextIfNeeded()
            self?.currentTool = tool
        }
        toolbar.onColorSelected = { [weak self] color in
            self?.currentColor = color
        }
        toolbar.onStrokeWidthSelected = { [weak self] width in
            self?.currentStrokeWidth = width
        }
        toolbar.onUndo = { [weak self] in
            self?.undoLastAnnotation()
        }
        toolbar.onCopy = { [weak self] in
            self?.commitActiveTextIfNeeded()
            self?.onCopyRequested?()
        }
        toolbar.onSave = { [weak self] in
            self?.commitActiveTextIfNeeded()
            self?.onSaveRequested?()
        }
        toolbar.onUpload = { [weak self] in
            self?.commitActiveTextIfNeeded()
            self?.onUploadRequested?()
        }
        toolbar.onClose = { [weak self] in
            self?.onDismissRequested?()
        }
    }
    
    // MARK: - Tracking Areas & Cursors
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateCursor(for: point)
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateCursor(for: point)
    }
    
    private func updateCursor(for point: CGPoint) {
        guard !selectionRect.isEmpty else {
            NSCursor.crosshair.set()
            return
        }
        
        if let handle = SelectionHandle.handle(at: point, in: selectionRect) {
            handle.cursor.set()
            return
        }
        
        if selectionRect.contains(point) {
            if currentTool == .select {
                NSCursor.openHand.set()
            } else {
                NSCursor.crosshair.set()
            }
        } else {
            NSCursor.crosshair.set()
        }
    }
    
    // MARK: - Drawing Engine
    
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw base captured background image
        if let baseImage = baseImage {
            // Because isFlipped = true, context.draw needs proper coordinate handling
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(baseImage, in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
            context.restoreGState()
        }
        
        // 2. Draw darkened overlay mask
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        if selectionRect.isEmpty {
            context.fill(bounds)
        } else {
            // Cut out the selectionRect using evenOdd rule
            let maskPath = CGMutablePath()
            maskPath.addRect(bounds)
            maskPath.addRect(selectionRect)
            context.addPath(maskPath)
            context.drawPath(using: .eoFill)
        }
        context.restoreGState()
        
        guard !selectionRect.isEmpty else { return }
        
        // 3. Draw annotations (clipped to selection rect)
        context.saveGState()
        context.clip(to: selectionRect)
        let scale = targetScreen?.backingScaleFactor ?? 2.0
        for annotation in annotations {
            annotation.draw(in: context, baseImage: baseImage, scale: scale)
        }
        if let current = currentDrawingItem {
            current.draw(in: context, baseImage: baseImage, scale: scale)
        }
        context.restoreGState()
        
        // 4. Draw selection border
        context.saveGState()
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.stroke(selectionRect)
        
        // 5. Draw 8 Resize Handles
        for handle in SelectionHandle.allCases {
            let hRect = handle.rect(for: selectionRect)
            context.setFillColor(NSColor.white.cgColor)
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(1.0)
            context.fill(hRect)
            context.stroke(hRect)
        }
        context.restoreGState()
        
        // 6. Draw Dimension Badge
        drawDimensionBadge(context: context)
    }
    
    private func drawDimensionBadge(context: CGContext) {
        let scale = targetScreen?.backingScaleFactor ?? 2.0
        let pixelW = Int(selectionRect.width * scale)
        let pixelH = Int(selectionRect.height * scale)
        let text = "\(pixelW) × \(pixelH) px"
        
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        
        let badgeRect = CGRect(
            x: selectionRect.minX,
            y: max(4, selectionRect.minY - textSize.height - 8),
            width: textSize.width + 12,
            height: textSize.height + 4
        )
        
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(path)
        context.fillPath()
        
        attrString.draw(at: CGPoint(x: badgeRect.minX + 6, y: badgeRect.minY + 2))
        context.restoreGState()
    }
    
    // MARK: - Mouse Event Handling
    
    public override func mouseDown(with event: NSEvent) {
        commitActiveTextIfNeeded()
        let point = convert(event.locationInWindow, from: nil)
        
        // Check if clicked inside toolbar
        if !toolbar.isHidden && toolbar.frame.contains(point) {
            super.mouseDown(with: event)
            return
        }
        
        if selectionRect.isEmpty {
            // Start creating a new selection
            mouseState = .creatingSelection(start: point)
            selectionRect = CGRect(origin: point, size: .zero)
            return
        }
        
        // 1. Check if clicked a resize handle
        if let handle = SelectionHandle.handle(at: point, in: selectionRect) {
            mouseState = .resizing(handle: handle, initial: selectionRect)
            return
        }
        
        // 2. Check if clicked inside selection
        if selectionRect.contains(point) {
            switch currentTool {
            case .select:
                mouseState = .moving(startPoint: point, initialRect: selectionRect)
                NSCursor.closedHand.set()
                
            case .text:
                spawnInlineTextField(at: point)
                
            case .shape, .arrow, .pen, .blur:
                mouseState = .drawing(tool: currentTool, startPoint: point)
                handleDrawingDrag(to: point)
            }
            return
        }
        
        // 3. Clicked outside selection -> restart selection
        mouseState = .creatingSelection(start: point)
        selectionRect = CGRect(origin: point, size: .zero)
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        switch mouseState {
        case .idle:
            break
            
        case .creatingSelection(let start):
            let x = min(start.x, point.x)
            let y = min(start.y, point.y)
            let w = abs(point.x - start.x)
            let h = abs(point.y - start.y)
            selectionRect = CGRect(x: x, y: y, width: w, height: h)
            
        case .resizing(let handle, let initial):
            selectionRect = handle.updatedRect(original: initial, currentPoint: point)
            
        case .moving(let startPoint, let initialRect):
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y
            var newRect = initialRect.offsetBy(dx: dx, dy: dy)
            
            // Constrain inside bounds
            newRect.origin.x = max(0, min(bounds.width - newRect.width, newRect.origin.x))
            newRect.origin.y = max(0, min(bounds.height - newRect.height, newRect.origin.y))
            selectionRect = newRect
            
        case .drawing:
            handleDrawingDrag(to: point)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        switch mouseState {
        case .creatingSelection:
            // Ensure minimum valid size
            if selectionRect.width < 10 || selectionRect.height < 10 {
                selectionRect = .zero
            }
            
        case .resizing:
            break
            
        case .moving:
            if currentTool == .select {
                NSCursor.openHand.set()
            }
            
        case .drawing:
            if let finished = currentDrawingItem {
                annotations.append(finished)
                currentDrawingItem = nil
            }
            
        case .idle:
            break
        }
        
        mouseState = .idle
        needsDisplay = true
    }
    
    private func handleDrawingDrag(to point: CGPoint) {
        guard case .drawing(let tool, let startPoint) = mouseState else { return }
        
        let clampedPoint = CGPoint(
            x: max(selectionRect.minX, min(selectionRect.maxX, point.x)),
            y: max(selectionRect.minY, min(selectionRect.maxY, point.y))
        )
        
        switch tool {
        case .shape(let type):
            let rect = CGRect(
                x: min(startPoint.x, clampedPoint.x),
                y: min(startPoint.y, clampedPoint.y),
                width: abs(clampedPoint.x - startPoint.x),
                height: abs(clampedPoint.y - startPoint.y)
            )
            currentDrawingItem = .shape(type: type, rect: rect, color: currentColor, strokeWidth: currentStrokeWidth)
            
        case .arrow(let type):
            currentDrawingItem = .arrow(type: type, start: startPoint, end: clampedPoint, color: currentColor, strokeWidth: currentStrokeWidth)
            
        case .pen:
            if case .pen(var points, let color, let width) = currentDrawingItem {
                if let last = points.last {
                    let dist = hypot(clampedPoint.x - last.x, clampedPoint.y - last.y)
                    if dist >= 2.5 {
                        points.append(clampedPoint)
                        currentDrawingItem = .pen(points: points, color: color, strokeWidth: width)
                    }
                }
            } else {
                currentDrawingItem = .pen(points: [startPoint, clampedPoint], color: currentColor, strokeWidth: currentStrokeWidth)
            }
            
        case .blur:
            let rect = CGRect(
                x: min(startPoint.x, clampedPoint.x),
                y: min(startPoint.y, clampedPoint.y),
                width: abs(clampedPoint.x - startPoint.x),
                height: abs(clampedPoint.y - startPoint.y)
            )
            currentDrawingItem = .blur(rect: rect)
            
        case .select, .text:
            break
        }
        needsDisplay = true
    }
    
    // MARK: - Inline Text Tool
    
    private func spawnInlineTextField(at point: CGPoint) {
        commitActiveTextIfNeeded()
        
        let field = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 240, height: 28))
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.textColor = currentColor
        field.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        field.focusRingType = .none
        field.placeholderString = "Type text..."
        field.delegate = self
        field.wantsLayer = true
        
        // Add subtle shadow for visibility on any background while typing
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowBlurRadius = 3.5
        shadow.shadowOffset = .zero
        field.shadow = shadow
        
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
    }
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) || commandSelector == #selector(cancelOperation(_:)) {
            commitActiveTextIfNeeded()
            return true
        }
        return false
    }
    
    public func commitActiveTextIfNeeded() {
        guard let field = activeTextField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let origin = field.frame.origin
            let font = field.font ?? NSFont.systemFont(ofSize: 16, weight: .bold)
            annotations.append(.text(text: text, origin: origin, font: font, color: currentColor))
        }
        field.removeFromSuperview()
        activeTextField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
    
    // MARK: - Toolbar & Helpers
    
    public func undoLastAnnotation() {
        commitActiveTextIfNeeded()
        if !annotations.isEmpty {
            annotations.removeLast()
            needsDisplay = true
        }
    }
    
    private func updateToolbarVisibilityAndPosition() {
        if selectionRect.width > 20 && selectionRect.height > 20 {
            toolbar.isHidden = false
            toolbar.updatePosition(anchoredTo: selectionRect, in: bounds)
        } else {
            toolbar.isHidden = true
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    public override var acceptsFirstResponder: Bool { return true }
    
    public override func keyDown(with event: NSEvent) {
        // ESC key
        if event.keyCode == 53 {
            onDismissRequested?()
            return
        }
        
        // Cmd key modifiers
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c":
                commitActiveTextIfNeeded()
                onCopyRequested?()
                return
            case "s":
                commitActiveTextIfNeeded()
                onSaveRequested?()
                return
            case "u":
                commitActiveTextIfNeeded()
                onUploadRequested?()
                return
            case "z":
                undoLastAnnotation()
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
}
