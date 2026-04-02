import SwiftData
import Foundation

@Model
final class WellbeingGoal {
    var id: UUID
    var dailyPhoneMinutesTarget: Int    // e.g. 120 = 2 hours
    var dailyPickupsTarget: Int         // e.g. 40 pickups
    var longestStreak: Int
    var createdAt: Date

    init() {
        self.id = UUID()
        self.dailyPhoneMinutesTarget = 120
        self.dailyPickupsTarget = 40
        self.longestStreak = 0
        self.createdAt = Date()
    }

    var targetFormatted: String {
        let h = dailyPhoneMinutesTarget / 60
        let m = dailyPhoneMinutesTarget % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
