import SwiftUI
import SwiftData

struct HomeView: View {
    let timerViewModel: TimerViewModel

    @Environment(\.modelContext) private var context
    @Query private var tags: [Tag]

    @State private var taskLabel: String = ""
    @State private var estimatedDuration: TimeInterval = 5 * 60
    @State private var selectedTag: Tag? = nil
    @State private var showValidationError = false

    // ── Tweak these to adjust the Begin Task button ──
    private let buttonCornerRadius: CGFloat  = 8
    private let buttonPaddingTop:    CGFloat = 10
    private let buttonPaddingBottom: CGFloat = 1
    // ─────────────────────────────────────────────────

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you working on?") {
                    AnimatedPlaceholderTextField(text: $taskLabel)
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

                Section {
                    Button {
                        startTask()
                    } label: {
                        Text("Begin Task")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: buttonCornerRadius)
                            .fill(Color(hex: "#00bf63"))
                    )
                    .listRowInsets(EdgeInsets(
                        top: buttonPaddingTop,
                        leading: 0,
                        bottom: buttonPaddingBottom,
                        trailing: 0
                    ))
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("New Task")
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
        taskLabel = ""
        estimatedDuration = 5 * 60
        selectedTag = nil
    }
}

// MARK: - Animated placeholder text field

struct AnimatedPlaceholderTextField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var displayText = ""
    @State private var cursorOn = true

    private static let examples = [
        "Write a project proposal",
        "Do the washing",
        "Brainstorm cool ideas",
        "Watch a podcast",
        "Read a book",
        "Draw something",
        "Reply to emails",
        "Go for a walk",
        "Plan next week",
        "Call a friend",
        "Tidy the workspace",
        "Write in my journal",
        "Review my goals",
        "Cook a new recipe",
        "Stretch for 10 minutes",
        "Research a new topic",
        "Organise my notes",
        "Prep for tomorrow",
        "Clear my inbox",
        "Work on a side project",
        "Catch up on reading",
        "Sketch out an idea",
        "Write a to-do list",
        "Learn something new",
        "Take a proper break",
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty && !isFocused {
                HStack(spacing: 0) {
                    Text(displayText)
                    Text(cursorOn ? "|" : " ")
                }
                .foregroundStyle(.tertiary)
                .font(.body)
                .allowsHitTesting(false)
            }

            TextField("", text: $text)
                .focused($isFocused)
        }
        .task { await animatePlaceholder() }
        .task { await blinkCursor() }
    }

    // MARK: - Typewriter loop

    private func animatePlaceholder() async {
        let examples = Self.examples
        var idx = Int.random(in: 0..<examples.count)

        while !Task.isCancelled {
            let target = examples[idx]

            // Type out character by character
            for charCount in 0...target.count {
                guard !Task.isCancelled else { return }
                displayText = String(target.prefix(charCount))
                try? await Task.sleep(for: .milliseconds(75))
            }

            // Pause at full text
            try? await Task.sleep(for: .seconds(2))

            // Delete character by character (faster)
            var length = target.count
            while length > 0 {
                guard !Task.isCancelled else { return }
                length -= 1
                displayText = String(target.prefix(length))
                try? await Task.sleep(for: .milliseconds(35))
            }

            // Brief pause before next
            try? await Task.sleep(for: .milliseconds(400))
            idx = (idx + 1) % examples.count
        }
    }

    // MARK: - Cursor blink

    private func blinkCursor() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            cursorOn.toggle()
        }
    }
}
