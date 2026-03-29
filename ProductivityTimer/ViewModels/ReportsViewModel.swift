import Foundation

enum CompletionFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case onTime   = "On Time"
    case overTime = "Over Time"
    var id: String { rawValue }
}

enum TimePeriodFilter: String, CaseIterable, Identifiable {
    case today     = "Today"
    case thisWeek  = "Week"
    case thisMonth = "Month"
    case allTime   = "All Time"
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

struct InsightSnapshot {
    let total: Int
    let onTime: Int
    let overTime: Int
    let totalOvertimeDuration: TimeInterval
    var onTimePercent: Double {
        total > 0 ? Double(onTime) / Double(total) : 0
    }
}

@Observable
final class ReportsViewModel {
    // Drives the insights card (period + status)
    var filterPeriod: TimePeriodFilter = .allTime
    var filterStatus: CompletionFilter = .all

    // Drives the task list only
    var filterTag: Tag? = nil

    // MARK: - Insights (period + status filtered, no tag)

    func insightTasks(_ tasks: [TaskEntry]) -> [TaskEntry] {
        byPeriod(tasks).filter { task in
            switch filterStatus {
            case .all:      return true
            case .onTime:   return task.completedOnTime
            case .overTime: return task.isOverTime
            }
        }
    }

    func snapshot(_ tasks: [TaskEntry]) -> InsightSnapshot {
        let subset = insightTasks(tasks)
        let overtime = subset.reduce(0.0) { sum, t in
            let over = (t.actualDuration ?? 0) - t.estimatedDuration
            return sum + max(0, over)
        }
        return InsightSnapshot(
            total: subset.count,
            onTime: subset.filter { $0.completedOnTime }.count,
            overTime: subset.filter { $0.isOverTime }.count,
            totalOvertimeDuration: overtime
        )
    }

    // MARK: - Overtime by tag (period only, no status/tag filter)

    func tagStats(from tasks: [TaskEntry]) -> [TagStat] {
        let subset = byPeriod(tasks)
        var dict: [String: (tag: Tag?, tasks: [TaskEntry])] = [:]
        for task in subset {
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

    // MARK: - Time drains (overtime tasks for selected period, with notes)

    func timeDrains(_ tasks: [TaskEntry]) -> [TaskEntry] {
        byPeriod(tasks)
            .filter { $0.isOverTime }
            .sorted {
                let a = ($0.actualDuration ?? 0) - $0.estimatedDuration
                let b = ($1.actualDuration ?? 0) - $1.estimatedDuration
                return a > b
            }
    }

    // MARK: - Task list (tag filter only, always stable)

    func grouped(_ tasks: [TaskEntry]) -> [(key: String, tasks: [TaskEntry])] {
        let completed = tasks
            .filter { $0.endTime != nil }
            .filter { task in
                guard let tag = filterTag else { return true }
                return task.tag?.id == tag.id
            }
            .sorted { $0.startTime > $1.startTime }

        var dict: [String: [TaskEntry]] = [:]
        for task in completed {
            let key = task.tag?.name ?? "Untagged"
            dict[key, default: []].append(task)
        }
        return dict.sorted { $0.key < $1.key }.map { (key: $0.key, tasks: $0.value) }
    }

    // MARK: - Private

    private func byPeriod(_ tasks: [TaskEntry]) -> [TaskEntry] {
        let calendar = Calendar.current
        let now = Date()
        return tasks.filter { $0.endTime != nil }.filter { task in
            switch filterPeriod {
            case .allTime:   return true
            case .today:     return calendar.isDateInToday(task.startTime)
            case .thisWeek:  return calendar.isDate(task.startTime, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth: return calendar.isDate(task.startTime, equalTo: now, toGranularity: .month)
            }
        }
    }
}
