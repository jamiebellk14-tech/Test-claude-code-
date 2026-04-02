import SwiftUI
import SwiftData
import FamilyControls
import DeviceActivity

@MainActor
@Observable
final class WellbeingViewModel {

    // MARK: - State

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var todaySnapshot: WellbeingSnapshot?
    var goal: WellbeingGoal?
    var yesterdaySnapshot: WellbeingSnapshot?
    var last7: [WellbeingSnapshot] = []
    var streak: Int = 0

    // MARK: - Authorization

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = .approved
            startMonitoring()
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - DeviceActivity Monitoring

    private func startMonitoring() {
        let center = DeviceActivityCenter()
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try? center.startMonitoring(.daily, during: schedule)
    }

    // MARK: - Data Sync

    /// Read today's data written by the DeviceActivity extension into App Groups UserDefaults.
    func syncFromSharedContainer(context: ModelContext) {
        let defaults = UserDefaults.wellbeingGroup
        guard
            let json = defaults?.string(forKey: UserDefaults.wellbeingTodayKey),
            let data = json.data(using: .utf8),
            let report = try? JSONDecoder().decode(WellbeingDayReport.self, from: data)
        else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = findOrCreateSnapshot(for: today, context: context)
        snapshot.totalPhoneMinutes = report.totalMinutes
        snapshot.phonePickups = report.pickups
        snapshot.source = .deviceActivity
        if let appsData = try? JSONEncoder().encode(report.apps) {
            snapshot.appBreakdownJSON = String(data: appsData, encoding: .utf8) ?? "[]"
        }
        deriveProductiveTime(for: snapshot, context: context)
        try? context.save()
        load(context: context)
    }

    // MARK: - Load

    func load(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        todaySnapshot = findOrCreateSnapshot(for: today, context: context)
        deriveProductiveTime(for: todaySnapshot!, context: context)
        try? context.save()

        // Yesterday
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            let desc = FetchDescriptor<WellbeingSnapshot>(
                predicate: #Predicate { $0.date == yesterday }
            )
            yesterdaySnapshot = (try? context.fetch(desc))?.first
        }

        // Last 7 snapshots (not today)
        var desc7 = FetchDescriptor<WellbeingSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        desc7.fetchLimit = 8
        let all7 = (try? context.fetch(desc7)) ?? []
        last7 = Array(all7.filter { !calendar.isDateInToday($0.date) }.prefix(7))

        // Goal
        let goalDesc = FetchDescriptor<WellbeingGoal>()
        if let existing = (try? context.fetch(goalDesc))?.first {
            goal = existing
        } else {
            let newGoal = WellbeingGoal()
            context.insert(newGoal)
            try? context.save()
            goal = newGoal
        }

        // Streak
        if let g = goal {
            streak = currentStreak(snapshots: all7, goal: g)
        }
    }

    // MARK: - Flip Metric Calculations

    func isUnderGoal(snapshot: WellbeingSnapshot) -> Bool {
        guard let g = goal else { return true }
        return snapshot.totalPhoneMinutes <= g.dailyPhoneMinutesTarget &&
               snapshot.phonePickups <= g.dailyPickupsTarget
    }

    func pickupsDelta() -> Int? {
        guard let today = todaySnapshot, let yesterday = yesterdaySnapshot else { return nil }
        return today.phonePickups - yesterday.phonePickups
    }

    func pickupsDeltaLabel() -> String? {
        guard let delta = pickupsDelta() else { return nil }
        let abs = Swift.abs(delta)
        if delta < 0 { return "\(abs) fewer pickups than yesterday" }
        if delta > 0 { return "\(abs) more pickups than yesterday" }
        return "Same pickups as yesterday"
    }

    func screenTimeDeltaMinutes() -> Int? {
        guard let today = todaySnapshot, let yesterday = yesterdaySnapshot else { return nil }
        return today.totalPhoneMinutes - yesterday.totalPhoneMinutes
    }

    func screenTimeDeltaLabel() -> String? {
        guard let delta = screenTimeDeltaMinutes() else { return nil }
        let abs = Swift.abs(delta)
        let h = abs / 60, m = abs % 60
        let formatted = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        if delta < 0 { return "\(formatted) less screen time than yesterday" }
        if delta > 0 { return "\(formatted) more screen time than yesterday" }
        return "Same screen time as yesterday"
    }

    // MARK: - Streak

    private func currentStreak(snapshots: [WellbeingSnapshot], goal: WellbeingGoal) -> Int {
        let cal = Calendar.current
        let sorted = snapshots
            .filter { !cal.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
        var streak = 0
        var expected = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: Date())!)
        for snap in sorted {
            guard cal.isDate(snap.date, inSameDayAs: expected) else { break }
            guard snap.totalPhoneMinutes <= goal.dailyPhoneMinutesTarget &&
                  snap.phonePickups <= goal.dailyPickupsTarget else { break }
            streak += 1
            expected = cal.date(byAdding: .day, value: -1, to: expected)!
        }
        // Update longest streak
        if streak > goal.longestStreak {
            goal.longestStreak = streak
        }
        return streak
    }

    // MARK: - Helpers

    private func findOrCreateSnapshot(for date: Date, context: ModelContext) -> WellbeingSnapshot {
        let desc = FetchDescriptor<WellbeingSnapshot>(
            predicate: #Predicate { $0.date == date }
        )
        if let existing = (try? context.fetch(desc))?.first { return existing }
        let new = WellbeingSnapshot(date: date)
        context.insert(new)
        return new
    }

    private func deriveProductiveTime(for snapshot: WellbeingSnapshot, context: ModelContext) {
        let cal = Calendar.current
        let start = snapshot.date
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let desc = FetchDescriptor<TaskEntry>(
            predicate: #Predicate { $0.startTime >= start && $0.startTime < end && $0.endTime != nil }
        )
        let tasks = (try? context.fetch(desc)) ?? []
        snapshot.productiveMinutes = Int(tasks.compactMap { $0.actualDuration }.reduce(0, +) / 60)
        snapshot.tasksCompleted = tasks.count
    }
}

// MARK: - DeviceActivity.Name extension
extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
}
