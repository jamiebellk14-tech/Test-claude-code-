import Foundation
import SwiftData
import Combine

@Observable
final class TimerViewModel {
    var elapsedSeconds: Int = 0
    var currentTask: TaskEntry?

    private var cancellable: AnyCancellable?

    var isRunning: Bool { currentTask != nil }

    var progress: Double {
        guard let task = currentTask, task.estimatedDuration > 0 else { return 0 }
        return Double(elapsedSeconds) / task.estimatedDuration
    }

    // MARK: - Start

    func startTask(
        label: String,
        estimatedDuration: TimeInterval,
        tag: Tag?,
        context: ModelContext
    ) {
        let task = TaskEntry(label: label, estimatedDuration: estimatedDuration, tag: tag)
        context.insert(task)
        try? context.save()

        let notifID = NotificationManager.shared.scheduleCheckIn(for: task)
        task.scheduledNotificationIDs.append(notifID)
        try? context.save()

        currentTask = task
        elapsedSeconds = 0
        startTimer()
    }

    // MARK: - End

    func endTask(context: ModelContext) {
        guard let task = currentTask else { return }
        stopTimer()
        NotificationManager.shared.cancelPendingNotifications(for: task)
        task.endTime = Date()
        try? context.save()
        currentTask = nil
        elapsedSeconds = 0
    }

    // MARK: - Check-in update

    func submitUpdate(note: String, context: ModelContext) {
        guard let task = currentTask else { return }
        let update = TaskUpdate(note: note, task: task)
        context.insert(update)

        // Schedule a follow-up notification
        let notifID = NotificationManager.shared.rescheduleCheckIn(for: task)
        task.scheduledNotificationIDs.append(notifID)
        try? context.save()
    }

    // MARK: - Timer internals

    private func startTimer() {
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let task = self.currentTask else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(task.startTime))
            }
    }

    private func stopTimer() {
        cancellable?.cancel()
        cancellable = nil
    }

    // MARK: - Restore on app relaunch

    /// Call this from ContentView.onAppear to resume an in-progress task if one exists.
    func restoreIfNeeded(from tasks: [TaskEntry]) {
        guard currentTask == nil,
              let running = tasks.first(where: { $0.isRunning }) else { return }
        currentTask = running
        elapsedSeconds = Int(Date().timeIntervalSince(running.startTime))
        startTimer()
    }
}
