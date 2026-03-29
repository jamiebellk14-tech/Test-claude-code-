import Foundation

enum CompletionFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case onTime   = "On Time"
    case overTime = "Over Time"
    var id: String { rawValue }
}

struct TagStat: Identifiable {
    let id: UUID
    let name: String
    let colorHex: String
    let taskCount: Int
    let totalOvertime: TimeInterval
    var averageOvertime: TimeInterval {
        taskCount > 0 ? totalOvertime / Double(taskCount) : 0
    }
}

@Observable
final class ReportsViewModel {
    var filterTag: Tag? = nil
    var filterStatus: CompletionFilter = .all

    func filtered(_ tasks: [TaskEntry]) -> [TaskEntry] {
        tasks
            .filter { $0.endTime != nil }  // completed only
            .filter { task in
                guard let tag = filterTag else { return true }
                return task.tag?.id == tag.id
            }
            .filter { task in
                switch filterStatus {
                case .all:      return true
                case .onTime:   return task.completedOnTime
                case .overTime: return task.isOverTime
                }
            }
            .sorted { $0.startTime > $1.startTime }
    }

    func grouped(_ tasks: [TaskEntry]) -> [(key: String, tasks: [TaskEntry])] {
        let completed = filtered(tasks)
        var dict: [String: [TaskEntry]] = [:]
        for task in completed {
            let key = task.tag?.name ?? "Untagged"
            dict[key, default: []].append(task)
        }
        return dict.sorted { $0.key < $1.key }.map { (key: $0.key, tasks: $0.value) }
    }

    func totalOvertime(_ tasks: [TaskEntry]) -> TimeInterval {
        filtered(tasks).reduce(0) { sum, task in
            let over = (task.actualDuration ?? 0) - task.estimatedDuration
            return sum + max(0, over)
        }
    }

    func tagStats(from tasks: [TaskEntry]) -> [TagStat] {
        let completed = tasks.filter { $0.endTime != nil }
        var dict: [String: (tag: Tag?, tasks: [TaskEntry])] = [:]
        for task in completed {
            let key = task.tag?.name ?? "Untagged"
            dict[key, default: (task.tag, [])].tasks.append(task)
        }
        return dict.map { key, value in
            let overtime = value.tasks.reduce(0.0) { sum, t in
                let over = (t.actualDuration ?? 0) - t.estimatedDuration
                return sum + max(0, over)
            }
            return TagStat(
                id: value.tag?.id ?? UUID(),
                name: key,
                colorHex: value.tag?.colorHex ?? "#888888",
                taskCount: value.tasks.count,
                totalOvertime: overtime
            )
        }.sorted { $0.name < $1.name }
    }
}
