import SwiftUI
import SwiftData

private let green = Color(hex: "#00bf63")
private let orange = Color(hex: "#FF8C00")

struct WellbeingTodayPage: View {
    @Environment(\.modelContext) private var context
    var vm: WellbeingViewModel
    var summaryService: SummaryService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let snap = vm.todaySnapshot {
                    HeroFlipCard(snapshot: snap, vm: vm)
                    PickupsComparisonCard(snapshot: snap, vm: vm)
                    if vm.streak >= 2 { StreakBanner(streak: vm.streak) }
                    AICoachCard(summaryService: summaryService, vm: vm)
                    if !snap.appBreakdown.isEmpty {
                        AppBreakdownCard(apps: snap.appBreakdown)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

// MARK: - Hero Flip Card

private struct HeroFlipCard: View {
    let snapshot: WellbeingSnapshot
    var vm: WellbeingViewModel
    private let ledge: CGFloat = 5

    private var underGoal: Bool { vm.isUnderGoal(snapshot: snapshot) }
    private var faceColor: Color { underGoal ? green : orange }

    var body: some View {
        VStack(spacing: 0) {
            // Label row
            HStack {
                Text("Phone-free today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                Spacer()
                if snapshot.source == .deviceActivity {
                    Label("Live", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Main number
            Text(snapshot.phoneFreeFormatted)
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 8)

            // Goal status
            HStack(spacing: 6) {
                if underGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("Goal met · \(vm.goal?.targetFormatted ?? "2h") limit")
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.9))
                    let over = (snapshot.totalPhoneMinutes - (vm.goal?.dailyPhoneMinutesTarget ?? 120))
                    Text("\(over)m over goal · \(snapshot.screenTimeFormatted) screen time")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.8))
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(faceColor)
                RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                // Subtle top gloss
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.clear],
                    startPoint: .top, endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .shadow(color: faceColor.darkened(by: 0.5), radius: 0, x: 0, y: ledge)
        }
        .padding(.bottom, ledge)
        .animation(.spring(response: 0.4), value: underGoal)
    }
}

// MARK: - Pickups Comparison Card

private struct PickupsComparisonCard: View {
    let snapshot: WellbeingSnapshot
    var vm: WellbeingViewModel

    var body: some View {
        HStack(spacing: 12) {
            MetricCell(
                label: "Pickups today",
                value: "\(snapshot.phonePickups)",
                unit: "times",
                color: pickupColor(snapshot.phonePickups, goal: vm.goal?.dailyPickupsTarget ?? 40)
            )
            Divider().frame(height: 60)
            MetricCell(
                label: "Screen time",
                value: snapshot.screenTimeFormatted,
                unit: "",
                color: vm.isUnderGoal(snapshot: snapshot) ? green : orange
            )
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1)
        )

        // Delta row
        if let deltaLabel = vm.pickupsDeltaLabel() {
            let delta = vm.pickupsDelta() ?? 0
            HStack(spacing: 6) {
                Image(systemName: delta <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(delta <= 0 ? green : orange)
                Text(deltaLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(delta <= 0 ? green : orange)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private func pickupColor(_ count: Int, goal: Int) -> Color {
        count <= goal ? green : orange
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Streak Banner

private struct StreakBanner: View {
    let streak: Int
    private let ledge: CGFloat = 3

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak)-day streak")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("Under your screen time goal · keep it going")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(green)
                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.clear],
                    startPoint: .top, endPoint: .center
                ).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .shadow(color: green.darkened(by: 0.5), radius: 0, x: 0, y: ledge)
        }
        .padding(.bottom, ledge)
    }
}

// MARK: - AI Coach Card

private struct AICoachCard: View {
    var summaryService: SummaryService
    var vm: WellbeingViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TaskMind Coach", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(green)
                Spacer()
                Button {
                    generateCoaching()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(green)
                }
            }

            if summaryService.isLoading {
                HStack(spacing: 8) {
                    ProgressView().tint(green)
                    Text("Thinking…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            } else if !summaryService.errorMessage.isEmpty {
                Text(summaryService.errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if !summaryService.summary.isEmpty {
                Text(summaryService.summary)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button("Get coaching insight") { generateCoaching() }
                    .buttonStyle(TactileButtonStyle())
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1)
        )
    }

    private func generateCoaching() {
        guard let snap = vm.todaySnapshot, let goal = vm.goal else { return }
        Task {
            await summaryService.generateWellbeingCoaching(
                snapshot: snap,
                yesterday: vm.yesterdaySnapshot,
                goal: goal,
                streak: vm.streak
            )
        }
    }
}

// MARK: - App Breakdown Card

private struct AppBreakdownCard: View {
    let apps: [AppUsageEntry]
    private let ledge: CGFloat = 3

    private var topApps: [AppUsageEntry] { Array(apps.prefix(5)) }
    private var maxMinutes: Int { topApps.map(\.minutes).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(topApps) { app in
                let ratio = Double(app.minutes) / Double(maxMinutes)
                let isSocial = isSocialMedia(app.bundleId)
                let barColor: Color = isSocial ? orange : green

                VStack(spacing: 4) {
                    HStack {
                        Text(app.name)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(formatMinutes(app.minutes))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(barColor)
                    }
                    // Tactile 3D bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(height: 10)
                            // Ledge
                            RoundedRectangle(cornerRadius: 5)
                                .fill(barColor.darkened(by: 0.45))
                                .frame(width: max(10, geo.size.width * ratio), height: 10)
                                .offset(y: ledge)
                            // Face
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(barColor)
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            }
                            .frame(width: max(10, geo.size.width * ratio), height: 10)
                        }
                    }
                    .frame(height: 10 + ledge)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1)
        )
    }

    private func formatMinutes(_ m: Int) -> String {
        let h = m / 60, min = m % 60
        if h > 0 { return "\(h)h \(min)m" }
        return "\(min)m"
    }

    private func isSocialMedia(_ bundleId: String) -> Bool {
        let social = ["com.facebook", "com.instagram", "com.burbn", "com.tiktok",
                      "com.twitter", "com.snapchat", "com.reddit", "com.pinterest"]
        return social.contains { bundleId.lowercased().hasPrefix($0) }
    }
}
