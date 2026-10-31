import Cocoa

public final class ToolButton: NSButton {
    public var isToolSelected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    public init(
        systemSymbol: String,
        fallbackText: String = "",
        tooltip: String,
        target: AnyObject?,
        action: Selector
    ) {
        super.init(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        self.target = target
        self.action = action
        self.toolTip = tooltip
        self.isBordered = false
        self.wantsLayer = true
        self.bezelStyle = .regularSquare
        
        if let image = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: tooltip) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            self.image = image.withSymbolConfiguration(config)
        } else {
            self.title = fallbackText
        }
        self.imagePosition = .imageOnly
        self.imageScaling = .scaleProportionallyDown
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
        
        if isToolSelected {
            NSColor.systemBlue.withAlphaComponent(0.85).setFill()
            bgPath.fill()
            self.contentTintColor = .white
        } else if isHovered {
            NSColor.white.withAlphaComponent(0.18).setFill()
            bgPath.fill()
            self.contentTintColor = .white
        } else {
            self.contentTintColor = NSColor.white.withAlphaComponent(0.85)
        }
        
        super.draw(dirtyRect)
    }
}
