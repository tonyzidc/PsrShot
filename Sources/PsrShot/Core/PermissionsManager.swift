import Cocoa
import CoreGraphics

public final class PermissionsManager {
    public static let shared = PermissionsManager()
    
    private init() {}
    
    public func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    public func requestScreenRecordingPermission() -> Bool {
        if hasScreenRecordingPermission() {
            return true
        }
        return CGRequestScreenCaptureAccess()
    }
    
    public func promptForScreenRecordingPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        if hasScreenRecordingPermission() {
            completion(true)
            return
        }
        
        let granted = CGRequestScreenCaptureAccess()
        if granted {
            completion(true)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "PsrShot requires Screen Recording permission to capture and annotate screenshots.\n\nPlease enable Screen Recording for PsrShot in System Settings and try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
        completion(false)
    }
    
    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
