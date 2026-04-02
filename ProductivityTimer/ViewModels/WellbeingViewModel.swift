import SwiftUI
import SwiftData

@MainActor
@Observable
final class WellbeingViewModel {

    // MARK: - State
    var todaySnapshot: WellbeingSnapshot?
    var yesterdaySnapshot: WellbeingSnapshot?
    var last7: [WellbeingSnapshot] = []
    var goal: WellbeingGoal?
    var streak: Int = 0

    // MARK: - Load

    func load(context: ModelContext) {
        ensureGoal(context: context)
        populateSampleDataIfNeeded(context: context)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let allDesc = FetchDescriptor<WellbeingSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = (try? context.fetch(allDesc)) ?? []

        todaySnapshot = all.first { calendar.isDateInToday($0.date) }
            ?? findOrCreate(for: today, context: context)

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            yesterdaySnapshot = all.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        }

        last7 = Array(all.filter { !calendar.isDateInToday($0.date) }.prefix(7))

        if let g = goal { streak = currentStreak(snapshots: all, goal: g) }
        try? context.save()
    }

    // MARK: - Flip Metrics

    func isUnderGoal(snapshot: WellbeingSnapshot) -> Bool {
        guard let g = goal else { return true }
        return snapshot.totalPhoneMinutes <= g.dailyPhoneMinutesTarget &&
               snapshot.phonePickups <= g.dailyPickupsTarget
    }

    func pickupsDelta() -> Int? {
        guard let t = todaySnapshot, let y = yesterdaySnapshot else { return nil }
        return t.phonePickups - y.phonePickups
    }

    func pickupsDeltaLabel() -> String? {
        guard let d = pickupsDelta() else { return nil }
        let a = abs(d)
        if d < 0 { return "\(a) fewer pickups than yesterday" }
        if d > 0 { return "\(a) more pickups than yesterday" }
        return "Same pickups as yesterday"
    }

    func screenTimeDeltaMinutes() -> Int? {
        guard let t = todaySnapshot, let y = yesterdaySnapshot else { return nil }
        return t.totalPhoneMinutes - y.totalPhoneMinutes
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
        if streak > goal.longestStreak { goal.longestStreak = streak }
        return streak
    }

    // MARK: - Helpers

    private func findOrCreate(for date: Date, context: ModelContext) -> WellbeingSnapshot {
        let snap = WellbeingSnapshot(date: date)
        context.insert(snap)
        return snap
    }

    private func ensureGoal(context: ModelContext) {
        let desc = FetchDescriptor<WellbeingGoal>()
        if let existing = (try? context.fetch(desc))?.first {
            goal = existing
        } else {
            let g = WellbeingGoal()
            context.insert(g)
            try? context.save()
            goal = g
        }
    }

    // MARK: - Sample Data

    private func populateSampleDataIfNeeded(context: ModelContext) {
        let desc = FetchDescriptor<WellbeingSnapshot>()
        let existing = (try? context.fetchCount(desc)) ?? 0
        guard existing == 0 else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Build 7 days of sample data (oldest first)
        let sampleDays: [(daysAgo: Int, screenMins: Int, pickups: Int, productive: Int, tasks: Int)] = [
            (7, 195, 68, 42, 3),   // over goal
            (6, 88,  31, 95, 6),   // under
            (5, 142, 55, 78, 5),   // over
            (4, 74,  27, 110, 7),  // under
            (3, 61,  22, 130, 8),  // under (streak starts)
            (2, 55,  19, 145, 9),  // under
            (1, 48,  16, 160, 10), // under (yesterday)
        ]

        for day in sampleDays {
            guard let date = cal.date(byAdding: .day, value: -day.daysAgo, to: today) else { continue }
            let snap = WellbeingSnapshot(date: date)
            snap.totalPhoneMinutes = day.screenMins
            snap.phonePickups = day.pickups
            snap.productiveMinutes = day.productive
            snap.tasksCompleted = day.tasks
            snap.source = .deviceActivity
            context.insert(snap)
        }

        // Today — under goal, nice green state
        let todaySnap = WellbeingSnapshot(date: today)
        todaySnap.totalPhoneMinutes = 52
        todaySnap.phonePickups = 14
        todaySnap.productiveMinutes = 178
        todaySnap.tasksCompleted = 11
        todaySnap.source = .deviceActivity
        todaySnap.appBreakdownJSON = """
        [
            {"bundleId":"com.burbn.instagram","name":"Instagram","minutes":18},
            {"bundleId":"com.zhiliaoapp.musically","name":"TikTok","minutes":12},
            {"bundleId":"com.apple.mobilesafari","name":"Safari","minutes":10},
            {"bundleId":"com.apple.MobileSMS","name":"Messages","minutes":7},
            {"bundleId":"com.google.ios.youtube","name":"YouTube","minutes":5}
        ]
        """
        context.insert(todaySnap)
        try? context.save()
    }
}
