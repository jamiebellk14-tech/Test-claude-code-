import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    let content: String
}

struct ScheduledTaskDraft: Identifiable {
    let id = UUID()
    let label: String
    let minutes: Int
    let tagName: String?
}

private let brandGreen = Color(hex: "#00bf63")

struct ProductivityAIView: View {
    @Query(sort: \TaskEntry.startTime, order: .reverse) private var allTasks: [TaskEntry]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Environment(\.modelContext) private var context

    @State private var summaryService = SummaryService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showAPIKeySheet = false
    @State private var apiKeyDraft = ""
    @State private var typingMessageID: UUID? = nil
    @State private var typingText: String = ""
    @State private var pendingActions: [UUID: [ScheduledTaskDraft]] = [:]
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "What's my biggest time drain?",
        "Am I getting better at estimating?",
        "Which tag do I always underestimate?",
        "Show me a report of tasks logged per tag",
        "How was my productivity this week?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            BrandNavBar.logo(
                trailing: summaryService.hasAPIKey ? AnyView(menuButton) : nil
            )

            if !summaryService.hasAPIKey {
                apiKeyPrompt
            } else {
                chatArea
                // Input bar + opaque zone that sits behind the floating tab bar
                VStack(spacing: 0) {
                    inputBar
                    Color.clear.frame(height: 80)
                }
                .background(.bar)
            }
        }
        .sheet(isPresented: $showAPIKeySheet) { apiKeySheet }
    }

    private var menuButton: some View {
        Menu {
            Button("Clear chat", role: .destructive) {
                messages = []
                pendingActions = [:]
            }
            Button("Change API key") {
                apiKeyDraft = summaryService.apiKey
                showAPIKeySheet = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 17))
                // foregroundStyle inherited as .white from BrandNavBar container
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.18), in: Circle())
        }
    }

    // MARK: - Chat area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(messages) { message in
                            ChatBubble(
                                message: message,
                                displayText: typingMessageID == message.id ? typingText : nil,
                                allTasks: Array(allTasks)
                            )
                            .id(message.id)

                            if let drafts = pendingActions[message.id] {
                                ScheduleActionCard(drafts: drafts) {
                                    addToSchedule(drafts: drafts, messageID: message.id)
                                } onDismiss: {
                                    pendingActions.removeValue(forKey: message.id)
                                }
                                .padding(.leading, 28)
                            }
                        }
                        if isLoading {
                            thinkingIndicator.id("typing")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation {
                    if isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isLoading) {
                if isLoading { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
            .onChange(of: typingText) {
                proxy.scrollTo(typingMessageID, anchor: .bottom)
            }
        }
    }

    // MARK: - Thinking indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(brandGreen)
            ThinkingDotsText()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(brandGreen)
            Text("Your personal productivity coach")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("I know your full task history and can spot patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        HapticManager.light()
                        inputText = suggestion
                        send()
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(brandGreen)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(brandGreen.opacity(0.1), in: Capsule())
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask TaskMind…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .onSubmit { send() }
            Button { send() } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(TactileSendButtonStyle())
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    // MARK: - Send

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }
        HapticManager.light()
        messages.append(ChatMessage(role: "user", content: text))
        inputText = ""
        isLoading = true
        // Snapshot history + build context on main actor before async work
        let historySnapshot = Array(messages.dropLast())
        let taskSnapshot = Array(allTasks)
        let tagSnapshot = Array(allTags)
        Task { @MainActor in
            do {
                let reply = try await summaryService.chat(
                    history: historySnapshot,
                    newMessage: text,
                    allTasks: taskSnapshot,
                    allTags: tagSnapshot
                )
                let parsed = parseScheduleAction(from: reply)
                let cleanText = parsed?.cleanText ?? reply
                let newMsg = ChatMessage(role: "assistant", content: cleanText)
                messages.append(newMsg)
                if let drafts = parsed?.drafts, !drafts.isEmpty {
                    pendingActions[newMsg.id] = drafts
                }
                isLoading = false
                startTypewriter(text: cleanText, id: newMsg.id)
            } catch {
                messages.append(ChatMessage(role: "assistant", content: "Sorry, I couldn't connect. Check your API key or internet.\n\n_\(error.localizedDescription)_"))
                isLoading = false
            }
        }
    }

    // MARK: - Schedule action parsing

    private func parseScheduleAction(from text: String) -> (cleanText: String, drafts: [ScheduledTaskDraft])? {
        guard let regex = try? NSRegularExpression(
            pattern: #"\{\{SCHEDULE:(\[.*?\])\}\}"#,
            options: [.dotMatchesLineSeparators]
        ) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let jsonRange = Range(match.range(at: 1), in: text) else { return nil }

        let jsonString = String(text[jsonRange])
        guard let jsonData = jsonString.data(using: .utf8),
              let rawItems = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        else { return nil }

        let drafts: [ScheduledTaskDraft] = rawItems.compactMap { item in
            guard let label = item["label"] as? String,
                  let minutes = item["minutes"] as? Int else { return nil }
            let tagName = item["tag"] as? String
            return ScheduledTaskDraft(label: label, minutes: minutes, tagName: tagName)
        }

        let fullMatch = Range(match.range, in: text).map { String(text[$0]) } ?? ""
        let cleanText = text.replacingOccurrences(of: fullMatch, with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        return (cleanText, drafts)
    }

    // MARK: - Add to schedule

    private func addToSchedule(drafts: [ScheduledTaskDraft], messageID: UUID) {
        for draft in drafts {
            let matchedTag = allTags.first {
                $0.name.lowercased() == (draft.tagName ?? "").lowercased()
            }
            let task = ScheduledTask(
                label: draft.label,
                estimatedDuration: TimeInterval(draft.minutes * 60),
                tag: matchedTag,
                notes: ""
            )
            context.insert(task)
        }
        try? context.save()
        HapticManager.medium()
        pendingActions.removeValue(forKey: messageID)
    }

    private func startTypewriter(text: String, id: UUID) {
        typingMessageID = id
        typingText = ""
        let chars = Array(text)
        Task {
            for i in chars.indices {
                guard typingMessageID == id else { return }
                await MainActor.run { typingText = String(chars[0...i]) }
                try? await Task.sleep(for: .milliseconds(10))
            }
            await MainActor.run { typingMessageID = nil }
        }
    }

    // MARK: - API key prompt

    private var apiKeyPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles").font(.system(size: 48)).foregroundStyle(brandGreen)
            Text("Meet TaskMind").font(.title2.bold())
            Text("Chat with an AI coach that knows your full task history. Needs a free Anthropic API key to get started.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { apiKeyDraft = ""; showAPIKeySheet = true } label: {
                Label("Add API Key", systemImage: "key.fill")
            }
            .buttonStyle(TactileButtonStyle())
            .frame(maxWidth: 260)
            Text("Get a free key at console.anthropic.com").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - API key sheet

    private var apiKeySheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Get a free API key at console.anthropic.com — create an account, go to API Keys, and paste it below.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("Anthropic API Key") }
                Section {
                    TextField("sk-ant-…", text: $apiKeyDraft)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                Section {
                    Text("Your key is stored only on this device and is never sent anywhere except Anthropic's API.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("API Key").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAPIKeySheet = false } }
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
}

// MARK: - Schedule Action Card

struct ScheduleActionCard: View {
    let drafts: [ScheduledTaskDraft]
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(brandGreen)
                Text("Add to Schedule")
                    .font(.subheadline.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(drafts) { draft in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                        Text("\(draft.label) — \(draft.minutes)m\(draft.tagName.map { " [\($0)]" } ?? "")")
                            .font(.subheadline)
                    }
                }
            }
            HStack(spacing: 8) {
                Button("Add to Schedule", action: onAdd)
                    .buttonStyle(TactileButtonStyle())
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(TactileOutlineButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(brandGreen.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - "TaskMind is thinking..." animated indicator

struct ThinkingDotsText: View {
    @State private var dotCount = 0
    var body: some View {
        Text("TaskMind is thinking" + String(repeating: ".", count: dotCount))
            .font(.subheadline).foregroundStyle(.secondary)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(420))
                    dotCount = (dotCount + 1) % 4
                }
            }
    }
}

// MARK: - Chat bubble

struct ChatBubble: View {
    let message: ChatMessage
    var displayText: String? = nil
    var allTasks: [TaskEntry] = []

    private var isUser: Bool { message.role == "user" }
    private var text: String { displayText ?? message.content }

    // Show a live data card when the AI response is clearly data-heavy
    private var showLiveCard: Bool {
        guard !isUser, displayText == nil else { return false }
        let pctCount = message.content.components(separatedBy: "%").count - 1
        let digitCount = message.content.filter(\.isNumber).count
        return pctCount >= 2 || digitCount > 10
    }

    // When live card is shown, extract only the key insight text
    private var insightText: String {
        let content = message.content
        if let range = content.range(of: "——") {
            let after = String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty { return after }
        }
        let paragraphs = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return paragraphs.last ?? content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(brandGreen)
                    .padding(.top, 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Live data card appears above the AI insight for report responses
                if showLiveCard {
                    LiveDataCard(allTasks: allTasks)
                }
                standardBubble
            }
            .frame(maxWidth: showLiveCard ? .infinity : nil, alignment: .leading)

            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var standardBubble: some View {
        let displayContent = showLiveCard ? insightText : text
        return markdownText(displayContent)
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isUser ? brandGreen : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .foregroundStyle(isUser ? .white : .primary)
            .frame(maxWidth: showLiveCard ? .infinity : nil, alignment: .leading)
    }

    // Split into paragraphs so each gets its own Text — gives proper visual spacing
    @ViewBuilder
    private func markdownText(_ string: String) -> some View {
        // Normalise: collapse 3+ newlines to 2, convert lone \n to double (paragraph break)
        let normalised = string
            .replacingOccurrences(of: "\n\n", with: "\u{FFFE}")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{FFFE}", with: "\n\n")
        let paragraphs = normalised
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        VStack(alignment: .leading, spacing: 5) {
            ForEach(paragraphs.indices, id: \.self) { i in
                if let attributed = try? AttributedString(markdown: paragraphs[i]) {
                    Text(attributed)
                } else {
                    Text(paragraphs[i])
                }
            }
        }
    }
}

// MARK: - Live data card (uses real allTasks data)

struct LiveDataCard: View {
    let allTasks: [TaskEntry]

    private var completed: [TaskEntry] { allTasks.filter { $0.endTime != nil } }
    private var onTimeCount: Int { completed.filter { $0.completedOnTime }.count }
    private var onTimePct: Int {
        guard !completed.isEmpty else { return 0 }
        return Int(Double(onTimeCount) / Double(completed.count) * 100)
    }
    private var overtimeCount: Int { completed.count - onTimeCount }

    private struct TagRow: Identifiable {
        let id = UUID()
        let name: String
        let colorHex: String
        let count: Int
        let overtimeCount: Int
    }

    private var tagRows: [TagRow] {
        var dict: [String: (hex: String, count: Int, ot: Int)] = [:]
        for task in completed {
            let key = task.tag?.name ?? "Untagged"
            let hex = task.tag?.colorHex ?? "8E8E93"
            dict[key, default: (hex, 0, 0)].count += 1
            if task.isOverTime { dict[key, default: (hex, 0, 0)].ot += 1 }
        }
        return dict.map { TagRow(name: $0.key, colorHex: $0.value.hex, count: $0.value.count, overtimeCount: $0.value.ot) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill").font(.caption).foregroundStyle(brandGreen)
                Text("Live Report").font(.caption.weight(.semibold)).foregroundStyle(brandGreen)
                Spacer()
                Text("\(completed.count) task\(completed.count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            // Stats strip
            HStack(spacing: 0) {
                statCell("\(completed.count)", label: "Total")
                Divider().frame(height: 28)
                statCell("\(onTimePct)%", label: "On Time", color: .green)
                Divider().frame(height: 28)
                statCell("\(overtimeCount)", label: "Over", color: overtimeCount > 0 ? .orange : Color(.secondaryLabel))
            }
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            // Tag breakdown bars
            if !tagRows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("By tag").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    let maxCount = tagRows.first?.count ?? 1
                    ForEach(tagRows) { row in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: row.colorHex))
                                .frame(width: 8, height: 8)
                            Text(row.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 72, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: row.colorHex).opacity(0.15))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: row.colorHex).opacity(0.75))
                                        .frame(width: geo.size.width * CGFloat(row.count) / CGFloat(maxCount))
                                }
                            }
                            .frame(height: 6)
                            Text("\(row.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 18, alignment: .trailing)
                            if row.overtimeCount > 0 {
                                Text("\(row.overtimeCount) late")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(brandGreen.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(brandGreen.opacity(0.2), lineWidth: 1))
    }

    private func statCell(_ value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
