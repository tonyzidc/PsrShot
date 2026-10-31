import Cocoa
import CoreImage

public enum ShapeType: String, CaseIterable, Hashable {
    case rectangle = "Rectangle"
    case roundedRect = "Rounded Rectangle"
    case ellipse = "Circle / Ellipse"
    case filledRect = "Filled Highlight"
    
    public var iconSymbol: String {
        switch self {
        case .rectangle: return "square"
        case .roundedRect: return "app"
        case .ellipse: return "circle"
        case .filledRect: return "square.fill"
        }
    }
}

public enum ArrowType: String, CaseIterable, Hashable {
    case single = "Single Arrow"
    case double = "Double-Ended Arrow"
    case line = "Straight Line"
    case dashed = "Dashed Arrow"
    
    public var iconSymbol: String {
        switch self {
        case .single: return "arrow.up.right"
        case .double: return "arrow.left.and.right"
        case .line: return "line.diagonal"
        case .dashed: return "arrow.up.right"
        }
    }
}

public enum AnnotationTool: Hashable {
    case select
    case shape(ShapeType)
    case arrow(ArrowType)
    case pen
    case text
    case blur
    
    public var isDrawingTool: Bool {
        return self != .select
    }
}

public enum AnnotationItem {
    case shape(type: ShapeType, rect: CGRect, color: NSColor, strokeWidth: CGFloat)
    case arrow(type: ArrowType, start: CGPoint, end: CGPoint, color: NSColor, strokeWidth: CGFloat)
    case pen(points: [CGPoint], color: NSColor, strokeWidth: CGFloat)
    case text(text: String, origin: CGPoint, font: NSFont, color: NSColor)
    case blur(rect: CGRect)
    
    public func draw(in context: CGContext, baseImage: CGImage? = nil, scale: CGFloat = 1.0) {
        context.saveGState()
        
        switch self {
        case .shape(let type, let rect, let color, let strokeWidth):
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineJoin(.round)
            context.setLineCap(.round)
            
            switch type {
            case .rectangle:
                context.stroke(rect)
                
            case .roundedRect:
                let r = min(12.0, min(rect.width, rect.height) / 4.0)
                let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
                context.addPath(path)
                context.strokePath()
                
            case .ellipse:
                context.strokeEllipse(in: rect)
                
            case .filledRect:
                context.setFillColor(color.withAlphaComponent(0.35).cgColor)
                context.fill(rect)
                context.stroke(rect)
            }
            
        case .arrow(let type, let start, let end, let color, let strokeWidth):
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            if type == .dashed {
                context.setLineDash(phase: 0, lengths: [8, 6])
            }
            
            // Draw shaft
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            
            // Remove dash for arrowhead fill
            if type == .dashed {
                context.setLineDash(phase: 0, lengths: [])
            }
            
            // Draw arrowheads
            switch type {
            case .single, .dashed:
                drawArrowHead(at: end, from: start, strokeWidth: strokeWidth, in: context)
                
            case .double:
                drawArrowHead(at: end, from: start, strokeWidth: strokeWidth, in: context)
                drawArrowHead(at: start, from: end, strokeWidth: strokeWidth, in: context)
                
            case .line:
                break // No arrowheads on line
            }
            
        case .pen(let points, let color, let strokeWidth):
            guard points.count > 1 else {
                if let single = points.first {
                    context.setFillColor(color.cgColor)
                    context.fillEllipse(in: CGRect(x: single.x - strokeWidth / 2, y: single.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth))
                }
                break
            }
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            context.beginPath()
            context.move(to: points[0])
            for i in 1..<points.count {
                context.addLine(to: points[i])
            }
            context.strokePath()
            
        case .text(let text, let origin, let font, let color):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let attrString = NSAttributedString(string: text, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(attrString)
            let textSize = attrString.size()
            let textRect = CGRect(origin: .zero, size: textSize)
            
            // Transparent background by default with soft shadow for legibility
            context.saveGState()
            context.setShadow(offset: .zero, blur: 4.0, color: NSColor.black.withAlphaComponent(0.8).cgColor)
            
            context.textMatrix = .identity
            context.translateBy(x: origin.x, y: origin.y + textSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            let drawPath = CGPath(rect: textRect, transform: nil)
            let drawFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), drawPath, nil)
            CTFrameDraw(drawFrame, context)
            context.restoreGState()
            
        case .blur(let rect):
            if let baseImage = baseImage {
                applyPixelate(to: rect, baseImage: baseImage, context: context, scale: scale)
            } else {
                context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
                context.fill(rect)
            }
        }
        
        context.restoreGState()
    }
    
    private func drawArrowHead(at tip: CGPoint, from origin: CGPoint, strokeWidth: CGFloat, in context: CGContext) {
        let dx = tip.x - origin.x
        let dy = tip.y - origin.y
        let angle = atan2(dy, dx)
        let headLength = max(14.0, strokeWidth * 3.5)
        let headAngle: CGFloat = .pi / 6.0 // 30 degrees
        
        let p1 = CGPoint(
            x: tip.x - headLength * cos(angle - headAngle),
            y: tip.y - headLength * sin(angle - headAngle)
        )
        let p2 = CGPoint(
            x: tip.x - headLength * cos(angle + headAngle),
            y: tip.y - headLength * sin(angle + headAngle)
        )
        
        context.beginPath()
        context.move(to: tip)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }
    
    private func applyPixelate(to rect: CGRect, baseImage: CGImage, context: CGContext, scale: CGFloat) {
        guard rect.width > 2 && rect.height > 2 else { return }
        
        let pixelRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        guard let subImage = baseImage.cropping(to: pixelRect) else { return }
        let ciImage = CIImage(cgImage: subImage)
        
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        let blockSize = max(8.0, 16.0 * (scale / 2.0))
        filter?.setValue(blockSize, forKey: kCIInputScaleKey)
        
        let ciContext = CIContext(options: nil)
        if let output = filter?.outputImage,
           let pixellated = ciContext.createCGImage(output, from: output.extent) {
            context.draw(pixellated, in: rect)
        } else {
            context.draw(subImage, in: rect)
        }
    }
}
