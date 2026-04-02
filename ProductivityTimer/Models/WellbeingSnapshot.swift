import SwiftData
import Foundation

enum SnapshotSource: String, Codable {
    case deviceActivity
    case manual
}

@Model
final class WellbeingSnapshot {
    var id: UUID
    var date: Date                  // normalized to start-of-day (midnight)
    var phonePickups: Int
    var totalPhoneMinutes: Int
    var source: SnapshotSource
    var appBreakdownJSON: String    // [{"bundleId":"...","minutes":N,"name":"..."}]
    var productiveMinutes: Int      // cached from TaskEntry on write
    var tasksCompleted: Int
    var userNote: String

    init(date: Date = Date(), source: SnapshotSource = .deviceActivity) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.phonePickups = 0
        self.totalPhoneMinutes = 0
        self.source = source
        self.appBreakdownJSON = "[]"
        self.productiveMinutes = 0
        self.tasksCompleted = 0
        self.userNote = ""
    }

    // MARK: - Computed helpers

    /// Minutes not spent on phone, assuming a 16-hour waking day
    var phoneFreeMinutes: Int {
        max(0, (16 * 60) - totalPhoneMinutes)
    }

    var phoneFreeFormatted: String {
        let h = phoneFreeMinutes / 60
        let m = phoneFreeMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    var screenTimeFormatted: String {
        let h = totalPhoneMinutes / 60
        let m = totalPhoneMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    var appBreakdown: [AppUsageEntry] {
        guard let data = appBreakdownJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([AppUsageEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.minutes > $1.minutes }
    }
}

struct AppUsageEntry: Codable, Identifiable {
    var id: String { bundleId }
    let bundleId: String
    let name: String
    let minutes: Int
}

// Shared container key used by both main app and DeviceActivity extension
extension UserDefaults {
    static let wellbeingGroup = UserDefaults(suiteName: "group.com.personal.productivitytimer")
    static let wellbeingTodayKey = "wellbeing.todayData"
}

/// Codable bridge — the DeviceActivity extension writes this,
/// WellbeingViewModel reads it from the App Groups shared container.
struct WellbeingDayReport: Codable {
    let date: String            // ISO8601 date string (date only)
    let totalMinutes: Int
    let pickups: Int
    let apps: [AppUsageEntry]
}
