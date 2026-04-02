import SwiftUI
import SwiftData

struct ActiveTimerView: View {
    let timerViewModel: TimerViewModel

    @Environment(\.modelContext) private var context

    @State private var noteText = ""
    @FocusState private var noteFocused: Bool

    private var task: TaskEntry? { timerViewModel.currentTask }
    private var isOvertime: Bool { timerViewModel.progress > 1 }
    private var tagColor: Color? {
        task?.tag.map { Color(hex: $0.colorHex) }
    }

    var body: some View {
        VStack(spacing: 0) {
            BrandNavBar.titled("Timer Running")
            Form {
                // Timer content
                Section {
                    VStack(spacing: 32) {
                        if let task {
                            VStack(spacing: 8) {
                                if let tag = task.tag {
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: tag.colorHex).opacity(0.2))
                                        .foregroundStyle(Color(hex: tag.colorHex))
                                        .clipShape(Capsule())
                                }
                                Text(task.label)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                            }
                        }

                        ZStack {
                            ProgressRingView(
                                progress: timerViewModel.progress,
                                tagColor: tagColor
                            )
                            .frame(width: 220, height: 220)

                            VStack(spacing: 4) {
                                Text(TimeInterval(timerViewModel.elapsedSeconds).hhmmss)
                                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isOvertime ? .red : .primary)

                                if let task {
                                    Text("of \(task.estimatedDuration.shortFormatted)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if isOvertime, let task {
                            let over = TimeInterval(timerViewModel.elapsedSeconds) - task.estimatedDuration
                            Text("Over by \(over.hhmmss)")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                // Notes section
                Section {
                    // Previous notes
                    if let task, !task.updates.isEmpty {
                        let sorted = task.updates.sorted { $0.createdAt < $1.createdAt }
                        ForEach(sorted) { update in
                            HStack(alignment: .top, spacing: 8) {
                                Rectangle()
                                    .fill(Color.orange.opacity(0.5))
                                    .frame(width: 2)
                                    .cornerRadius(1)
                                Text(update.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // Note input
                    TextField(
                        isOvertime ? "Why is it taking longer?" : "Add a note…",
                        text: $noteText,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .focused($noteFocused)

                    if !noteText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Save note") {
                            HapticManager.light()
                            timerViewModel.submitUpdate(note: noteText.trimmingCharacters(in: .whitespaces), context: context)
                            noteText = ""
                            noteFocused = false
                        }
                        .foregroundStyle(.orange)
                    }
                } header: {
                    Text(isOvertime ? "What's slowing you down?" : "Notes")
                }

                // End button
                Section {
                    Button {
                        HapticManager.medium()
                        timerViewModel.endTask(context: context)
                    } label: {
                        Label("End Task", systemImage: "stop.fill")
                    }
                    .buttonStyle(TactileButtonStyle(color: .red))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        }
    }
}
