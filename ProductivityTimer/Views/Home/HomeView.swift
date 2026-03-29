import SwiftUI
import SwiftData

struct HomeView: View {
    let timerViewModel: TimerViewModel

    @Environment(\.modelContext) private var context
    @Query private var tags: [Tag]

    @State private var taskLabel: String = ""
    @State private var estimatedDuration: TimeInterval = 5 * 60  // default 5 minutes
    @State private var selectedTag: Tag? = nil
    @State private var showValidationError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you working on?") {
                    TextField("e.g. Doing the dishes", text: $taskLabel)
                }

                Section("How long do you think it'll take?") {
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
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        startTask()
                    } label: {
                        Label("Start Timer", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
            }
            .task {
                await NotificationManager.shared.requestAuthorization()
            }
        }
    }

    private func startTask() {
        let trimmed = taskLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, estimatedDuration > 0 else {
            showValidationError = true
            return
        }
        showValidationError = false
        timerViewModel.startTask(
            label: trimmed,
            estimatedDuration: estimatedDuration,
            tag: selectedTag,
            context: context
        )
        // Reset form
        taskLabel = ""
        estimatedDuration = 5 * 60
        selectedTag = nil
    }
}
