import Cocoa
import CoreImage

public enum AnnotationTool: Hashable {
    case select
    case rectangle(filled: Bool)
    case arrow
    case pen
    case text
    case blur
    
    public var isDrawingTool: Bool {
        return self != .select
    }
}

public enum AnnotationItem {
    case rectangle(rect: CGRect, color: NSColor, strokeWidth: CGFloat, isFilled: Bool)
    case arrow(start: CGPoint, end: CGPoint, color: NSColor, strokeWidth: CGFloat)
    case pen(points: [CGPoint], color: NSColor, strokeWidth: CGFloat)
    case text(text: String, origin: CGPoint, font: NSFont, color: NSColor)
    case blur(rect: CGRect)
    
    public func draw(in context: CGContext, baseImage: CGImage? = nil, scale: CGFloat = 1.0) {
        context.saveGState()
        
        switch self {
        case .rectangle(let rect, let color, let strokeWidth, let isFilled):
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.withAlphaComponent(0.25).cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineJoin(.round)
            
            if isFilled {
                context.fill(rect)
            }
            context.stroke(rect)
            
        case .arrow(let start, let end, let color, let strokeWidth):
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            // Draw main shaft
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            
            // Calculate arrow head vertices
            let dx = end.x - start.x
            let dy = end.y - start.y
            let angle = atan2(dy, dx)
            let headLength = max(14.0, strokeWidth * 3.5)
            let headAngle: CGFloat = .pi / 6.0 // 30 degrees
            
            let p1 = CGPoint(
                x: end.x - headLength * cos(angle - headAngle),
                y: end.y - headLength * sin(angle - headAngle)
            )
            let p2 = CGPoint(
                x: end.x - headLength * cos(angle + headAngle),
                y: end.y - headLength * sin(angle + headAngle)
            )
            
            // Draw arrow head triangle
            context.beginPath()
            context.move(to: end)
            context.addLine(to: p1)
            context.addLine(to: p2)
            context.closePath()
            context.fillPath()
            
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
            
            // Render text
            let framesetter = CTFramesetterCreateWithAttributedString(attrString)
            let textSize = attrString.size()
            let textRect = CGRect(origin: origin, size: textSize)
            
            // Background plate for readability
            context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
            let bgRect = textRect.insetBy(dx: -4, dy: -2)
            let path = CGPath(roundedRect: bgRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            context.addPath(path)
            context.fillPath()
            
            // Text matrix correction in flipped context
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: origin.x, y: origin.y + textSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            let drawPath = CGPath(rect: CGRect(origin: .zero, size: textSize), transform: nil)
            let drawFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), drawPath, nil)
            CTFrameDraw(drawFrame, context)
            context.restoreGState()
            
        case .blur(let rect):
            // Fallback / fast mosaic pixelation if baseImage is available
            if let baseImage = baseImage {
                applyPixelate(to: rect, baseImage: baseImage, context: context, scale: scale)
            } else {
                // Dimmed placeholder
                context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
                context.fill(rect)
            }
        }
        
        context.restoreGState()
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
            // Fast downscaled redraw as fallback mosaic
            context.draw(subImage, in: rect)
        }
    }
}
