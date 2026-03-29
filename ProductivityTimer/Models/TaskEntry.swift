import Foundation
import SwiftData

@Model
final class TaskEntry {
    var id: UUID
    var label: String
    var estimatedDuration: TimeInterval  // seconds
    var startTime: Date
    var endTime: Date?
    var tag: Tag?
    var scheduledNotificationIDs: [String]

    @Relationship(deleteRule: .cascade, inverse: \TaskUpdate.task)
    var updates: [TaskUpdate] = []

    init(
        id: UUID = UUID(),
        label: String,
        estimatedDuration: TimeInterval,
        startTime: Date = Date(),
        tag: Tag? = nil
    ) {
        self.id = id
        self.label = label
        self.estimatedDuration = estimatedDuration
        self.startTime = startTime
        self.tag = tag
        self.scheduledNotificationIDs = []
    }

    var actualDuration: TimeInterval? {
        endTime.map { $0.timeIntervalSince(startTime) }
    }

    var isOverTime: Bool {
        (actualDuration ?? 0) > estimatedDuration
    }

    var completedOnTime: Bool {
        endTime != nil && !isOverTime
    }

    var isRunning: Bool {
        endTime == nil
    }
}
