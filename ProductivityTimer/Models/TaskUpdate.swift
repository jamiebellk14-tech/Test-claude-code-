import Foundation
import SwiftData

@Model
final class TaskUpdate {
    var id: UUID
    var createdAt: Date
    var note: String
    var task: TaskEntry?

    init(id: UUID = UUID(), note: String, task: TaskEntry) {
        self.id = id
        self.createdAt = Date()
        self.note = note
        self.task = task
    }
}
