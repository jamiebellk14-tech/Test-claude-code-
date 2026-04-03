import SwiftUI

private let green = Color(hex: "#00bf63")
private let orange = Color(hex: "#FF8C00")

struct WellbeingTrendsPage: View {
    var vm: WellbeingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vm.last7.isEmpty {
                    EmptyTrendsCard()
                } else {
                    PhoneFreeBarChart(snapshots: vm.last7, goal: vm.goal)
                    PickupsTrendCard(snapshots: vm.last7, goal: vm.goal)
                    ProductiveVsScreenCard(snapshots: vm.last7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

// MARK: - Empty State

private struct EmptyTrendsCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(green.opacity(0.6))
            Text("Trends will appear here")
                .font(.system(size: 15, weight: .semibold))
            Text("Come back after a few days of tracking to see your patterns.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Phone-Free Bar Chart

private struct PhoneFreeBarChart: View {
    let snapshots: [WellbeingSnapshot]
    let goal: WellbeingGoal?
    private let ledge: CGFloat = 4
    private let barCornerRadius: CGFloat = 6
    private let chartHeight: CGFloat = 100

    private var sorted: [WellbeingSnapshot] { snapshots.sorted { $0.date < $1.date } }

    // Goal line: fraction of chart height at which the goal sits
    private var goalLineRatio: Double? {
        guard let g = goal else { return nil }
        let goalPhoneFreeMinutes = max(0, (16 * 60) - g.dailyPhoneMinutesTarget)
        return min(1.0, Double(goalPhoneFreeMinutes) / Double(16 * 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phone-free time")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            GeometryReader { outer in
                ZStack(alignment: .bottomLeading) {
                    // Bars row
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(sorted) { snap in
                            let ratio = min(1.0, Double(snap.phoneFreeMinutes) / Double(16 * 60))
                            let underGoal = (goal.map { snap.totalPhoneMinutes <= $0.dailyPhoneMinutesTarget } ?? true)
                            let barColor: Color = underGoal ? green : orange

                            VStack(spacing: 5) {
                                GeometryReader { geo in
                                    let barH = max(8, geo.size.height * ratio)
                                    ZStack(alignment: .bottom) {
                                        // Ledge
                                        RoundedRectangle(cornerRadius: barCornerRadius)
                                            .fill(barColor.darkened(by: 0.5))
                                            .frame(height: barH + ledge)
                                        // Face
                                        ZStack {
                                            RoundedRectangle(cornerRadius: barCornerRadius)
                                                .fill(barColor)
                                            RoundedRectangle(cornerRadius: barCornerRadius)
                                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.15), Color.clear],
                                                startPoint: .top, endPoint: .center
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: barCornerRadius))
                                        }
                                        .frame(height: barH)
                                    }
                                }
                                .frame(height: chartHeight)

                                Text(dayAbbr(snap.date))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                Text(snap.phoneFreeFormatted)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(underGoal ? green : orange)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Dashed goal line overlay
                    if let ratio = goalLineRatio {
                        // The line sits `ratio` fraction from the bottom of the chart area
                        // Chart area ends at chartHeight from bottom of GeometryReader
                        let labelsHeight: CGFloat = 30 // day abbr + value label below bars
                        let lineY = outer.size.height - labelsHeight - (chartHeight * ratio)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: lineY))
                            path.addLine(to: CGPoint(x: outer.size.width, y: lineY))
                        }
                        .stroke(
                            Color(.secondaryLabel).opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                    }
                }
            }
            .frame(height: chartHeight + 40)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 1)
        )
    }

    private func dayAbbr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
}

// MARK: - Pickups Trend

private struct PickupsTrendCard: View {
    let snapshots: [WellbeingSnapshot]
    let goal: WellbeingGoal?
    private let ledge: CGFloat = 3
    private let barHeight: CGFloat = 10

    private var sorted: [WellbeingSnapshot] { snapshots.sorted { $0.date < $1.date } }
    private var maxPickups: Int { max(sorted.map(\.phonePickups).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily pickups")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(sorted.enumerated()), id: \.offset) { i, snap in
                let ratio = Double(snap.phonePickups) / Double(maxPickups)
                let underGoal = (goal.map { snap.phonePickups <= $0.dailyPickupsTarget } ?? true)
                let barColor: Color = underGoal ? green : orange
                let prev = i > 0 ? sorted[i - 1].phonePickups : nil
                let delta = prev.map { snap.phonePickups - $0 }

                VStack(spacing: 4) {
                    HStack {
                        Text(dayLabel(snap.date))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        HStack(spacing: 4) {
                            if let delta, delta != 0 {
                                Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(delta < 0 ? green : orange)
                                Text("\(abs(delta))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(delta < 0 ? green : orange)
                            }
                            Text("\(snap.phonePickups)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(barColor)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(height: barHeight)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(barColor.darkened(by: 0.45))
                                    .frame(width: max(barHeight, geo.size.width * ratio), height: barHeight)
                                    .offset(y: ledge)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5).fill(barColor)
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                }
                                .frame(width: max(barHeight, geo.size.width * ratio), height: barHeight)
                            }
                        }
                    }
                    .frame(height: barHeight + ledge)
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

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Productive vs Screen Time

private struct ProductiveVsScreenCard: View {
    let snapshots: [WellbeingSnapshot]
    private var sorted: [WellbeingSnapshot] { snapshots.sorted { $0.date < $1.date } }

    private var maxTotal: Int {
        sorted.map { $0.productiveMinutes + $0.totalPhoneMinutes }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Productive vs screen time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 10) {
                    legendDot(green, "Productive")
                    legendDot(orange, "Screen time")
                }
            }

            ForEach(sorted) { snap in
                let prodRatio = Double(snap.productiveMinutes) / Double(maxTotal)
                let screenRatio = Double(snap.totalPhoneMinutes) / Double(maxTotal)

                HStack(spacing: 6) {
                    Text(dayShort(snap.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .leading)

                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            if snap.productiveMinutes > 0 {
                                segmentBar(green, width: geo.size.width * prodRatio)
                            }
                            if snap.totalPhoneMinutes > 0 {
                                segmentBar(orange, width: geo.size.width * screenRatio)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: 14)

                    HStack(spacing: 3) {
                        Text("\(snap.productiveMinutes)m")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(green)
                        Text("/")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Text("\(snap.totalPhoneMinutes)m")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(orange)
                    }
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

    @ViewBuilder
    private func segmentBar(_ color: Color, width: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(color)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        }
        .frame(width: max(4, width), height: 14)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func dayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}
