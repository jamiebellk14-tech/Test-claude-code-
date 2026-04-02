import SwiftUI
import DeviceActivity
import ManagedSettings

// MARK: - Scene

struct TotalActivityScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let content: (DeviceActivityReport.Context) -> TotalActivityView

    var body: some DeviceActivityReportScene {
        TotalActivityReport(context: context) { activityReport in
            content(.totalActivity)
        }
    }
}

// MARK: - Report

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let content: (DeviceActivityResults) -> TotalActivityView

    var body: some DeviceActivityReportScene {
        DeviceActivityReport(context: context) { activityReport in
            content(activityReport)
        }
    }
}

// MARK: - View

struct TotalActivityView: View {
    var context: DeviceActivityReport.Context

    var body: some View {
        DeviceActivityReport(context: context) { activityReport in
            InternalReportView(results: activityReport)
        }
    }
}

private struct InternalReportView: View {
    let results: DeviceActivityResults

    var body: some View {
        // Render a lightweight summary — main UI is in the host app
        VStack(spacing: 8) {
            Text(totalFormatted)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Screen time today")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .onAppear { writeToSharedContainer() }
    }

    // MARK: - Shared Container Write

    private func writeToSharedContainer() {
        // Extract total duration and pickups across all apps
        var totalMinutes = 0
        var totalPickups = 0
        var appEntries: [AppEntry] = []

        for (application, data) in results.applicationActivity {
            let minutes = Int(data.totalActivityDuration / 60)
            let pickups = data.numberOfPickups
            totalMinutes += minutes
            totalPickups += pickups
            appEntries.append(AppEntry(
                bundleId: application.bundleIdentifier ?? "unknown",
                name: application.localizedDisplayName ?? "Unknown App",
                minutes: minutes
            ))
        }

        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let report = SharedReport(
            date: today,
            totalMinutes: totalMinutes,
            pickups: totalPickups,
            apps: appEntries.sorted { $0.minutes > $1.minutes }.prefix(10).map { $0 }
        )

        if let json = try? JSONEncoder().encode(report),
           let jsonString = String(data: json, encoding: .utf8) {
            UserDefaults(suiteName: "group.com.personal.productivitytimer")?
                .set(jsonString, forKey: "wellbeing.todayData")
        }
    }

    private var totalFormatted: String {
        var total = 0
        for (_, data) in results.applicationActivity {
            total += Int(data.totalActivityDuration / 60)
        }
        let h = total / 60, m = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Shared codable types (duplicated in extension — no shared framework needed)

private struct SharedReport: Codable {
    let date: String
    let totalMinutes: Int
    let pickups: Int
    let apps: [AppEntry]
}

private struct AppEntry: Codable {
    let bundleId: String
    let name: String
    let minutes: Int
}
