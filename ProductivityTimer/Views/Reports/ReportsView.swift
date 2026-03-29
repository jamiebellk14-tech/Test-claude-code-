import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(sort: \TaskEntry.startTime, order: .reverse) private var allTasks: [TaskEntry]
    @Query private var tags: [Tag]

    @State private var reportsVM = ReportsViewModel()
    @State private var showChart = false
    @State private var expandedGroups: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                // Insights: period + status pickers + snapshot card
                insightsSection

                // Overtime by tag (responds to period filter)
                overtimeByTagSection

                // Bar chart toggle
                if !allTasks.isEmpty {
                    Section {
                        DisclosureGroup("Task count by tag", isExpanded: $showChart) {
                            let stats = reportsVM.tagStats(from: allTasks)
                            if stats.isEmpty {
                                Text("No completed tasks yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                TagBarChartView(stats: stats)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }

                // Tag filter for the list
                Section {
                    Picker("Tag", selection: $reportsVM.filterTag) {
                        Text("All tags").tag(Optional<Tag>.none)
                        ForEach(tags) { tag in
                            Text(tag.name).tag(Optional(tag))
                        }
                    }
                } header: {
                    Text("Browse by Tag")
                }

                // Grouped task list — only filtered by tag, never jumps
                let grouped = reportsVM.grouped(allTasks)
                if grouped.isEmpty {
                    Section {
                        Text("No completed tasks.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(grouped, id: \.key) { group in
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedGroups.contains(group.key) },
                                    set: { isOpen in
                                        if isOpen { expandedGroups.insert(group.key) }
                                        else { expandedGroups.remove(group.key) }
                                    }
                                )
                            ) {
                                ForEach(group.tasks) { task in
                                    TaskRowView(task: task)
                                }
                            } label: {
                                HStack {
                                    Text(group.key).font(.headline)
                                    Spacer()
                                    Text("\(group.tasks.count) task\(group.tasks.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }

    // MARK: - Insights section

    private var insightsSection: some View {
        Section {
            // Period picker
            Picker("Period", selection: $reportsVM.filterPeriod) {
                ForEach(TimePeriodFilter.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)

            // Status picker
            Picker("Status", selection: $reportsVM.filterStatus) {
                ForEach(CompletionFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            // Snapshot card
            let snap = reportsVM.snapshot(allTasks)
            if snap.total == 0 {
                Text("No tasks for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    // Stat row
                    HStack(spacing: 0) {
                        snapshotCell(value: "\(snap.total)", label: "Tasks")
                        Divider()
                        snapshotCell(value: "\(snap.onTime)", label: "On Time", color: .green)
                        Divider()
                        snapshotCell(value: "\(snap.overTime)", label: "Over Time", color: .orange)
                    }
                    .frame(maxWidth: .infinity)

                    // On-time ratio bar
                    if snap.total > 0 {
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.25))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: geo.size.width * snap.onTimePercent)
                                }
                            }
                            .frame(height: 8)

                            HStack {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text("\(Int(snap.onTimePercent * 100))% on time")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if snap.totalOvertimeDuration > 0 {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text(snap.totalOvertimeDuration.hhmmss)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("Insights")
        }
    }

    private func snapshotCell(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Overtime by tag

    private var overtimeByTagSection: some View {
        let stats = reportsVM.tagStats(from: allTasks).filter { $0.totalOvertime > 0 }
        return Group {
            if !stats.isEmpty {
                Section("Overtime by Tag") {
                    ForEach(stats) { stat in
                        HStack {
                            Circle()
                                .fill(Color(hex: stat.colorHex))
                                .frame(width: 10, height: 10)
                            Text(stat.name)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(stat.totalOvertime.hhmmss)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                                Text("avg \(stat.averageOvertime.hhmmss)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
