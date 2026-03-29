import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let followUpInterval: TimeInterval = 15 * 60  // 15 minutes

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Category Registration

    func registerCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_UPDATE",
            title: "Add Update",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "TASK_CHECKIN",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Schedule

    /// Schedules a check-in notification at startTime + estimatedDuration.
    /// Returns the notification ID.
    @discardableResult
    func scheduleCheckIn(for task: TaskEntry) -> String {
        let fireDate = task.startTime.addingTimeInterval(task.estimatedDuration)
        let delay = max(1, fireDate.timeIntervalSinceNow)
        return scheduleNotification(
            title: "Time check — \(task.label)",
            body: "Your estimate is up. Still going? Tap to add an update.",
            taskID: task.id.uuidString,
            delay: delay
        )
    }

    /// Schedules a follow-up check-in 15 minutes from now.
    /// Returns the notification ID.
    @discardableResult
    func rescheduleCheckIn(for task: TaskEntry) -> String {
        scheduleNotification(
            title: "Still going — \(task.label)",
            body: "Another 15 minutes have passed. Want to add an update?",
            taskID: task.id.uuidString,
            delay: followUpInterval
        )
    }

    // MARK: - Cancel

    func cancelPendingNotifications(for task: TaskEntry) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: task.scheduledNotificationIDs)
    }

    // MARK: - Private

    private func scheduleNotification(
        title: String,
        body: String,
        taskID: String,
        delay: TimeInterval
    ) -> String {
        let id = UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "TASK_CHECKIN"
        content.userInfo = ["taskID": taskID]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
        return id
    }
}
