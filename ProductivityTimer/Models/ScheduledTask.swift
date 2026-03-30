import Foundation
import SwiftData

@Model
final class ScheduledTask {
    var id: UUID
    var label: String
    var estimatedDuration: TimeInterval
    var tag: Tag?
    var createdAt: Date

    init(label: String, estimatedDuration: TimeInterval, tag: Tag? = nil) {
        self.id = UUID()
        self.label = label
        self.estimatedDuration = estimatedDuration
        self.tag = tag
        self.createdAt = Date()
    }
}
