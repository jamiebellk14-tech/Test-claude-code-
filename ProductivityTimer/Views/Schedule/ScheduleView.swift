import SwiftUI
import SwiftData

struct ScheduleView: View {
    let timerViewModel: TimerViewModel
    @Binding var selectedTab: Int

    @Query(sort: \ScheduledTask.createdAt) private var scheduledTasks: [ScheduledTask]
    @Query private var tags: [Tag]
    @Environment(\.modelContext) private var context

    @State private var showAddSheet = false
    @State private var editingTask: ScheduledTask? = nil

    var body: some View {
        NavigationStack {
            Group {
                if scheduledTasks.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(scheduledTasks) { task in
                            scheduledRow(task)
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ScheduledTaskFormView(existingTask: nil, tags: tags)
            }
            .sheet(item: $editingTask) { task in
                ScheduledTaskFormView(existingTask: task, tags: tags)
            }
        }
    }

    // MARK: - Row

    private func scheduledRow(_ task: ScheduledTask) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.label)
                    .font(.body)

                HStack(spacing: 6) {
                    Text(task.estimatedDuration.shortFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let tag = task.tag {
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: tag.colorHex).opacity(0.2))
                            .foregroundStyle(Color(hex: tag.colorHex))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Button {
                beginTask(task)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(hex: "#00bf63"))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                editingTask = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                context.delete(task)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tasks scheduled")
                .font(.headline)
            Text("Tap + to plan a task ahead of time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showAddSheet = true
            } label: {
                Label("Add Task", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#00bf63"), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Begin

    private func beginTask(_ task: ScheduledTask) {
        timerViewModel.startTask(
            label: task.label,
            estimatedDuration: task.estimatedDuration,
            tag: task.tag,
            context: context
        )
        context.delete(task)
        try? context.save()
        selectedTab = 0
    }
}

// MARK: - Add / Edit form

struct ScheduledTaskFormView: View {
    let existingTask: ScheduledTask?
    let tags: [Tag]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var estimatedDuration: TimeInterval = 5 * 60
    @State private var selectedTag: Tag? = nil
    @State private var showValidationError = false

    private var isEditing: Bool { existingTask != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task name") {
                    TextField("e.g. Write project proposal", text: $label)
                }

                Section("Estimated duration") {
                    DurationPickerView(duration: $estimatedDuration)
                }

                Section("Tag") {
                    Picker("Tag", selection: $selectedTag) {
                        Text("None").tag(Optional<Tag>.none)
                        ForEach(tags) { tag in
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(tag.name)
                            }
                            .tag(Optional(tag))
                        }
                    }
                }

                if showValidationError {
                    Section {
                        Text("Please enter a task name and set a duration greater than 0.")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .bold()
                }
            }
            .onAppear {
                if let task = existingTask {
                    label = task.label
                    estimatedDuration = task.estimatedDuration
                    selectedTag = task.tag
                }
            }
        }
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, estimatedDuration > 0 else {
            showValidationError = true
            return
        }

        if let task = existingTask {
            task.label = trimmed
            task.estimatedDuration = estimatedDuration
            task.tag = selectedTag
        } else {
            let task = ScheduledTask(label: trimmed, estimatedDuration: estimatedDuration, tag: selectedTag)
            context.insert(task)
        }
        try? context.save()
        dismiss()
    }
}
