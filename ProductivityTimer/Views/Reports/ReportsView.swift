import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(sort: \TaskEntry.startTime, order: .reverse) private var allTasks: [TaskEntry]
    @Query private var tags: [Tag]

    @State private var reportsVM = ReportsViewModel()
    @State private var summaryService = SummaryService()
    @State private var showChart = false
    @State private var expandedGroups: Set<String> = []
    @State private var selectedPage = 0
    @State private var showAPIKeySheet = false
    @State private var apiKeyDraft = ""

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                // Page 1 — Overview
                overviewPage
                    .tag(0)

                // Page 2 — What took longer
                timeDrainsPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(selectedPage == 0 ? "Reports" : "What Took Longer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Page", selection: $selectedPage) {
                        Text("Overview").tag(0)
                        Text("Time Drains").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }

    // MARK: - Page 1: Overview

    private var overviewPage: some View {
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            context.delete(task)
                                            try? context.save()
                                        } label: {
                                            Label("Delete Task", systemImage: "trash")
                                        }
                                    }
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
    }

    // MARK: - Page 2: What took longer

    private var timeDrainsPage: some View {
        let drains = reportsVM.timeDrains(allTasks)
        return List {
            // Period picker — shared with overview
            Section {
                Picker("Period", selection: $reportsVM.filterPeriod) {
                    ForEach(TimePeriodFilter.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Period")
            }

            // AI Summary card
            aiSummarySection(drains: drains)

            if drains.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("No overtime tasks")
                            .font(.headline)
                        Text("Everything finished within estimate for this period.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(drains) { task in
                        let overtime = (task.actualDuration ?? 0) - task.estimatedDuration
                        let notes = task.updates.sorted { $0.createdAt < $1.createdAt }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center) {
                                if let hex = task.tag?.colorHex {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 9, height: 9)
                                }
                                Text(task.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("+\(overtime.hhmmss)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                            }

                            // Overtime bar showing proportion over estimate
                            let ratio = min(overtime / max(task.estimatedDuration, 1), 1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.orange.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.orange.opacity(0.7))
                                        .frame(width: geo.size.width * ratio)
                                }
                            }
                            .frame(height: 5)

                            if notes.isEmpty {
                                Text("No check-in note left")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                            } else {
                                ForEach(notes) { update in
                                    HStack(alignment: .top, spacing: 8) {
                                        Rectangle()
                                            .fill(Color.orange.opacity(0.6))
                                            .frame(width: 2)
                                            .cornerRadius(1)
                                        Text(update.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("\(drains.count) task\(drains.count == 1 ? "" : "s") ran over")
                }
            }
        }
    }

    // MARK: - AI Summary

    @ViewBuilder
    private func aiSummarySection(drains: [TaskEntry]) -> some View {
        Section {
            if !summaryService.hasAPIKey {
                Button {
                    apiKeyDraft = ""
                    showAPIKeySheet = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set up TaskMind Summary")
                                .font(.subheadline.weight(.medium))
                            Text("Tap to add your Anthropic API key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else if summaryService.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analysing your day…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else if !summaryService.summary.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text("TaskMind")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                        Spacer()
                        Button {
                            Task {
                                await summaryService.generateSummary(
                                    period: reportsVM.filterPeriod,
                                    tasks: reportsVM.byPeriodPublic(allTasks)
                                )
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(summaryService.summary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } else if !summaryService.errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Couldn't generate summary")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                    Text(summaryService.errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        Task {
                            await summaryService.generateSummary(
                                period: reportsVM.filterPeriod,
                                tasks: reportsVM.byPeriodPublic(allTasks)
                            )
                        }
                    }
                    .font(.caption)
                }
            } else {
                Button {
                    Task {
                        await summaryService.generateSummary(
                            period: reportsVM.filterPeriod,
                            tasks: reportsVM.byPeriodPublic(allTasks)
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text(drains.isEmpty ? "Summarise my \(reportsVM.filterPeriod.rawValue.lowercased())" : "Summarise what slowed me down")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.purple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Summary")
        }
        .sheet(isPresented: $showAPIKeySheet) {
            apiKeySheet
        }
    }

    private var apiKeySheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Get a free API key at console.anthropic.com — create an account, go to API Keys, and paste it below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Anthropic API Key")
                }

                Section {
                    TextField("sk-ant-…", text: $apiKeyDraft)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text("Your key is stored only on this device and is never sent anywhere except Anthropic's API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAPIKeySheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        summaryService.apiKey = apiKeyDraft.trimmingCharacters(in: .whitespaces)
                        showAPIKeySheet = false
                    }
                    .disabled(apiKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Insights section

    private var insightsSection: some View {
        Section {
            Picker("Period", selection: $reportsVM.filterPeriod) {
                ForEach(TimePeriodFilter.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)

            Picker("Status", selection: $reportsVM.filterStatus) {
                ForEach(CompletionFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            let snap = reportsVM.snapshot(allTasks)
            if snap.total == 0 {
                Text("No tasks for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        snapshotCell(value: "\(snap.total)", label: "Tasks")
                        Divider()
                        snapshotCell(value: "\(snap.onTime)", label: "On Time", color: .green)
                        Divider()
                        snapshotCell(value: "\(snap.overTime)", label: "Over Time", color: .orange)
                    }
                    .frame(maxWidth: .infinity)

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
