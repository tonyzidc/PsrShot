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
        
        // Show an NSAlert guiding the user
        let alert = NSAlert()
        alert.messageText = "Cần quyền Quay màn hình (Screen Recording)"
        alert.informativeText = "PsrShot cần được cấp quyền 'Screen Recording' trong Cài đặt hệ thống để chụp và chỉnh sửa màn hình.\n\nVui lòng bật quyền cho PsrShot và thử lại."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Mở Cài đặt hệ thống")
        alert.addButton(withTitle: "Để sau")
        
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
