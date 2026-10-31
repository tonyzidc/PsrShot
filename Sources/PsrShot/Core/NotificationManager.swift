import Cocoa
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    public static var isNotificationSupported: Bool {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return false
        }
        guard NSClassFromString("XCTestCase") == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return false
        }
        guard Bundle.main.bundleIdentifier != nil else {
            return false
        }
        return true
    }
    
    private override init() {
        super.init()
        if Self.isNotificationSupported {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
        }
    }
    
    public func requestAuthorization() {
        guard Self.isNotificationSupported else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("[NotificationManager] Error requesting notification auth: \(error)")
            }
        }
    }
    
    public func postUploadSuccess(viewURL: String) {
        guard Self.isNotificationSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = "PsrShot: Upload Succeeded! ☁️"
        content.body = "Screenshot view link has been copied to your clipboard.\nClick to open in browser."
        content.sound = .default
        content.userInfo = ["viewURL": viewURL]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[NotificationManager] Error posting notification: \(error)")
            }
        }
    }
    
    public func postUploadFailure(error: Error) {
        guard Self.isNotificationSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = "PsrShot: Upload Failed ❌"
        content.body = error.localizedDescription
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func postUpdateAvailable(version: String, releaseURL: String, releaseNotes: String? = nil) {
        guard Self.isNotificationSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = "PsrShot Update Available 🚀"
        if let notes = releaseNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.body = "A new version \(version) is ready to download.\nClick to view release details and update."
        } else {
            content.body = "A new version \(version) is available.\nClick to download the latest update."
        }
        content.sound = .default
        content.userInfo = ["updateURL": releaseURL]
        
        let request = UNNotificationRequest(
            identifier: "psrshot-update-\(version)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[NotificationManager] Error posting update notification: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = (userInfo["updateURL"] ?? userInfo["viewURL"]) as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }
}
