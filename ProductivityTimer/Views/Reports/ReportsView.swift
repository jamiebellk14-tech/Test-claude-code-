import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(sort: \TaskEntry.startTime, order: .reverse) private var allTasks: [TaskEntry]
    @Query private var tags: [Tag]

    @State private var reportsVM = ReportsViewModel()
    @State private var showChart = false

    var body: some View {
        NavigationStack {
            List {
                // Summary stats
                statsSection

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

                // Filter controls
                filterSection

                // Grouped task list
                let grouped = reportsVM.grouped(allTasks)
                if grouped.isEmpty {
                    Section {
                        Text("No completed tasks match your filters.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(grouped, id: \.key) { group in
                        Section(group.key) {
                            ForEach(group.tasks) { task in
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }

    // MARK: - Stats header

    private var statsSection: some View {
        Section("Summary") {
            let completed = allTasks.filter { $0.endTime != nil }
            let total = reportsVM.totalOvertime(allTasks)
            let onTime = completed.filter { $0.completedOnTime }.count
            let overTime = completed.filter { $0.isOverTime }.count

            HStack(spacing: 0) {
                statCell(value: "\(completed.count)", label: "Total Tasks")
                Divider()
                statCell(value: "\(onTime)", label: "On Time", color: .green)
                Divider()
                statCell(value: "\(overTime)", label: "Over Time", color: .orange)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Total overtime: ")
                    .foregroundStyle(.secondary)
                Text(total > 0 ? total.hhmmss : "None")
                    .bold()
                    .foregroundStyle(total > 0 ? .orange : .green)
            }
            .font(.subheadline)
        }
    }

    private func statCell(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Filter controls

    private var filterSection: some View {
        Section("Filter") {
            Picker("Status", selection: $reportsVM.filterStatus) {
                ForEach(CompletionFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            Picker("Tag", selection: $reportsVM.filterTag) {
                Text("All tags").tag(Optional<Tag>.none)
                ForEach(tags) { tag in
                    Text(tag.name).tag(Optional(tag))
                }
            }
        }
    }
}
