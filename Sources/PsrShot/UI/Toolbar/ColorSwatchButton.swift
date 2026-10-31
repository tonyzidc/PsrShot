import Cocoa

public final class ColorSwatchButton: NSButton {
    public let swatchColor: NSColor
    
    public var isSwatchSelected: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var isHovered: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var trackingArea: NSTrackingArea?
    
    public init(color: NSColor, tooltip: String, target: AnyObject?, action: Selector) {
        self.swatchColor = color
        super.init(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        self.target = target
        self.action = action
        self.toolTip = tooltip
        self.isBordered = false
        self.wantsLayer = true
        self.title = ""
        self.image = nil
        self.bezelStyle = .regularSquare
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
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dotRadius: CGFloat = isHovered ? 8.0 : 7.5
        let dotRect = CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
        
        let path = NSBezierPath(ovalIn: dotRect)
        swatchColor.setFill()
        path.fill()
        
        // Base border for definition
        let isWhite = (swatchColor == .white || swatchColor.cgColor.components?.prefix(3).allSatisfy { $0 > 0.95 } == true)
        if isWhite {
            NSColor.black.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }
        
        // Selection Ring
        if isSwatchSelected {
            let ringRadius: CGFloat = 9.5
            let ringRect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
            let ringPath = NSBezierPath(ovalIn: ringRect)
            
            if isWhite {
                // Contrasting ring for white swatch
                NSColor.systemBlue.setStroke()
                ringPath.lineWidth = 2.0
                ringPath.stroke()
            } else {
                // White outer ring for colored swatches
                NSColor.white.setStroke()
                ringPath.lineWidth = 2.0
                ringPath.stroke()
            }
        }
    }
}
