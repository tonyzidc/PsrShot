import Cocoa
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("[NotificationManager] Error requesting notification auth: \(error)")
            }
        }
    }
    
    public func postUploadSuccess(viewURL: String) {
        let content = UNMutableNotificationContent()
        content.title = "PsrShot: Tải lên thành công! ☁️"
        content.body = "Đường link xem ảnh đã được sao chép vào clipboard.\nNhấn để xem ngay trên trình duyệt."
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
        let content = UNMutableNotificationContent()
        content.title = "PsrShot: Tải lên thất bại ❌"
        content.body = error.localizedDescription
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even if app is active
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
        if let urlString = response.notification.request.content.userInfo["viewURL"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }
}
