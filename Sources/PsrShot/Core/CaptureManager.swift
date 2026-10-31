import Cocoa
import CoreGraphics
import ScreenCaptureKit

public final class CaptureManager: @unchecked Sendable {
    public static let shared = CaptureManager()
    
    private init() {}
    
    public func targetScreenForCapture() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
    
    public func captureActiveDisplay(completion: @escaping (Result<(CGImage, NSScreen), Error>) -> Void) {
        let initialScreen = targetScreenForCapture()
        guard let screenNumber = initialScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            fallbackCapture(screen: initialScreen, displayID: nil, completion: completion)
            return
        }
        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    if let scDisplay = content.displays.first(where: { $0.displayID == displayID }) {
                        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                        let config = SCStreamConfiguration()
                        config.width = scDisplay.width
                        config.height = scDisplay.height
                        config.showsCursor = false
                        config.capturesAudio = false
                        
                        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                        await MainActor.run {
                            let targetScreen = self.findScreen(for: displayID) ?? NSScreen.main ?? NSScreen()
                            completion(.success((image, targetScreen)))
                        }
                        return
                    }
                } catch {
                    NSLog("[CaptureManager] ScreenCaptureKit error: \(error), falling back to CoreGraphics")
                }
                
                // Fallback to CoreGraphics
                await MainActor.run {
                    let targetScreen = self.findScreen(for: displayID) ?? NSScreen.main ?? NSScreen()
                    self.fallbackCapture(screen: targetScreen, displayID: displayID, completion: completion)
                }
            }
        } else {
            fallbackCapture(screen: initialScreen, displayID: displayID, completion: completion)
        }
    }
    
    public func findScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
               CGDirectDisplayID(num.uint32Value) == displayID {
                return screen
            }
        }
        return nil
    }
    
    private func fallbackCapture(screen: NSScreen, displayID: CGDirectDisplayID? = nil, completion: @escaping (Result<(CGImage, NSScreen), Error>) -> Void) {
        let screenRect = screen.frame
        if let image = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) {
            completion(.success((image, screen)))
            return
        }
        
        let error = NSError(
            domain: "PsrShot.CaptureManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to capture screen. Please check Screen Recording permissions."]
        )
        completion(.failure(error))
    }
}
