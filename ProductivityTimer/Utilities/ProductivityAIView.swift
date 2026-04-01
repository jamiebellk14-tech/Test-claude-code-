import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    let content: String
}

private let brandGreen = Color(hex: "#00bf63")

struct ProductivityAIView: View {
    @Query(sort: \TaskEntry.startTime, order: .reverse) private var allTasks: [TaskEntry]

    @State private var summaryService = SummaryService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showAPIKeySheet = false
    @State private var apiKeyDraft = ""
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "What's my biggest time drain?",
        "Am I getting better at estimating?",
        "Which tag do I always underestimate?",
        "What patterns do you see in my notes?",
        "How was my productivity this week?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !summaryService.hasAPIKey {
                    apiKeyPrompt
                } else {
                    chatArea
                    inputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TaskMindLogo(fontSize: 20)
                }
                if summaryService.hasAPIKey {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Clear chat", role: .destructive) {
                                messages = []
                            }
                            Button("Change API key") {
                                apiKeyDraft = summaryService.apiKey
                                showAPIKeySheet = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAPIKeySheet) { apiKeySheet }
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
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if isLoading {
                            typingIndicator
                                .id("typing")
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
                if isLoading {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Empty state with suggestions

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

    // MARK: - Typing indicator

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(brandGreen)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            Spacer()
        }
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

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? brandGreen : .secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    // MARK: - Send

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

        HapticManager.light()
        let userMessage = ChatMessage(role: "user", content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            do {
                let reply = try await summaryService.chat(
                    history: messages.dropLast(),
                    newMessage: text,
                    allTasks: allTasks
                )
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: reply))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: "Sorry, I couldn't connect. Check your API key or internet connection.\n\n_\(error.localizedDescription)_"))
                    isLoading = false
                }
            }
        }
    }

    // MARK: - API key prompt

    private var apiKeyPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(brandGreen)
            Text("Meet TaskMind")
                .font(.title2.bold())
            Text("Chat with an AI coach that knows your full task history. Needs a free Anthropic API key to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                apiKeyDraft = ""
                showAPIKeySheet = true
            } label: {
                Label("Add API Key", systemImage: "key.fill")
            }
            .buttonStyle(TactileButtonStyle())
            .frame(maxWidth: 260)
            Text("Get a free key at console.anthropic.com")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - API key sheet

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
}

// MARK: - Chat bubble

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#00bf63"))
                    .padding(.bottom, 4)
            }

            Text(message.content)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Color(hex: "#00bf63") : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .foregroundStyle(isUser ? .white : .primary)

            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
