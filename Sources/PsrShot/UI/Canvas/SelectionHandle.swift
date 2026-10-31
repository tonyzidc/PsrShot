import Cocoa

public enum SelectionHandle: CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case middleRight
    case bottomRight
    case bottomCenter
    case bottomLeft
    case middleLeft
    
    public static let handleSize: CGFloat = 8.0
    public static let hitRadius: CGFloat = 12.0
    
    public func rect(for selection: CGRect) -> CGRect {
        let size = SelectionHandle.handleSize
        let half = size / 2.0
        
        switch self {
        case .topLeft:
            return CGRect(x: selection.minX - half, y: selection.minY - half, width: size, height: size)
        case .topCenter:
            return CGRect(x: selection.midX - half, y: selection.minY - half, width: size, height: size)
        case .topRight:
            return CGRect(x: selection.maxX - half, y: selection.minY - half, width: size, height: size)
        case .middleRight:
            return CGRect(x: selection.maxX - half, y: selection.midY - half, width: size, height: size)
        case .bottomRight:
            return CGRect(x: selection.maxX - half, y: selection.maxY - half, width: size, height: size)
        case .bottomCenter:
            return CGRect(x: selection.midX - half, y: selection.maxY - half, width: size, height: size)
        case .bottomLeft:
            return CGRect(x: selection.minX - half, y: selection.maxY - half, width: size, height: size)
        case .middleLeft:
            return CGRect(x: selection.minX - half, y: selection.midY - half, width: size, height: size)
        }
    }
    
    public func hitTest(point: CGPoint, in selection: CGRect) -> Bool {
        let hRect = rect(for: selection).insetBy(dx: -SelectionHandle.hitRadius + SelectionHandle.handleSize / 2,
                                                 dy: -SelectionHandle.hitRadius + SelectionHandle.handleSize / 2)
        return hRect.contains(point)
    }
    
    public static func handle(at point: CGPoint, in selection: CGRect) -> SelectionHandle? {
        for handle in SelectionHandle.allCases {
            if handle.hitTest(point: point, in: selection) {
                return handle
            }
        }
        return nil
    }
    
    public var cursor: NSCursor {
        switch self {
        case .topCenter, .bottomCenter:
            return NSCursor.resizeUpDown
        case .middleLeft, .middleRight:
            return NSCursor.resizeLeftRight
        case .topLeft, .bottomRight:
            // Custom diagonal or arrow cursor
            return NSCursor.crosshair
        case .topRight, .bottomLeft:
            return NSCursor.crosshair
        }
    }
    
    public func updatedRect(original: CGRect, currentPoint: CGPoint) -> CGRect {
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY
        
        switch self {
        case .topLeft:
            minX = min(currentPoint.x, maxX - 10)
            minY = min(currentPoint.y, maxY - 10)
        case .topCenter:
            minY = min(currentPoint.y, maxY - 10)
        case .topRight:
            maxX = max(currentPoint.x, minX + 10)
            minY = min(currentPoint.y, maxY - 10)
        case .middleRight:
            maxX = max(currentPoint.x, minX + 10)
        case .bottomRight:
            maxX = max(currentPoint.x, minX + 10)
            maxY = max(currentPoint.y, minY + 10)
        case .bottomCenter:
            maxY = max(currentPoint.y, minY + 10)
        case .bottomLeft:
            minX = min(currentPoint.x, maxX - 10)
            maxY = max(currentPoint.y, minY + 10)
        case .middleLeft:
            minX = min(currentPoint.x, maxX - 10)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
