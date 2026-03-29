import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NotificationManager.shared.registerCategories()
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Show notification banner even when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle tap on notification (or its "Add Update" action)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let taskID = userInfo["taskID"] as? String {
            NotificationCenter.default.post(
                name: .openCheckIn,
                object: nil,
                userInfo: ["taskID": taskID]
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let openCheckIn = Notification.Name("openCheckIn")
}
