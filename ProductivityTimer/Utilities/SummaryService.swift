import Foundation

private extension DateFormatter {
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()
}

@Observable
final class SummaryService {
    var summary: String = ""
    var isLoading: Bool = false
    var errorMessage: String = ""

    private let apiKeyKey = "anthropic_api_key"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: apiKeyKey) }
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: - Time Drains summary (single-shot)

    func generateSummary(period: TimePeriodFilter, tasks: [TaskEntry]) async {
        let drains = tasks
            .filter { $0.isOverTime }
            .sorted {
                let a = ($0.actualDuration ?? 0) - $0.estimatedDuration
                let b = ($1.actualDuration ?? 0) - $1.estimatedDuration
                return a > b
            }

        let totalCompleted = tasks.filter { $0.endTime != nil }.count
        let prompt = buildSummaryPrompt(period: period, totalCompleted: totalCompleted, drains: drains)

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            summary = ""
        }

        do {
            let result = try await callClaude(messages: [["role": "user", "content": prompt]])
            await MainActor.run {
                summary = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Productivity AI chat (multi-turn)

    func chat(history: [ChatMessage], newMessage: String, allTasks: [TaskEntry], allTags: [Tag]) async throws -> String {
        let system = buildTaskContext(allTasks: allTasks, allTags: allTags)

        var apiMessages: [[String: String]] = history.map {
            ["role": $0.role, "content": $0.content]
        }
        apiMessages.append(["role": "user", "content": newMessage])

        return try await callClaude(messages: apiMessages, system: system, maxTokens: 600)
    }

    // MARK: - Context builder

    private func relativeDay(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE"
            return fmt.string(from: date)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM"
        return fmt.string(from: date)
    }

    func buildTaskContext(allTasks: [TaskEntry], allTags: [Tag]) -> String {
        let today = DateFormatter.full.string(from: Date())
        let completed = allTasks.filter { $0.endTime != nil }

        let tagNames = allTags.map { $0.name }.sorted().joined(separator: ", ")

        guard !completed.isEmpty else {
            return """
            You are TaskMind — a sharp, direct productivity coach built into this app.
            Today is \(today).
            The user has no completed tasks yet. Encourage them to start tracking.
            Available tags: \(tagNames.isEmpty ? "none yet" : tagNames)
            """
        }

        let onTime = completed.filter { $0.completedOnTime }.count
        let overtime = completed.filter { $0.isOverTime }.count
        let onTimePct = Int(Double(onTime) / Double(completed.count) * 100)

        // Tag breakdown
        var tagDict: [String: (count: Int, overtime: TimeInterval)] = [:]
        for task in completed {
            let key = task.tag?.name ?? "Untagged"
            let ot = max(0, (task.actualDuration ?? 0) - task.estimatedDuration)
            tagDict[key, default: (0, 0)].count += 1
            tagDict[key, default: (0, 0)].overtime += ot
        }
        let tagLines = tagDict.sorted { $0.key < $1.key }.map { name, val in
            let otStr = val.overtime > 0 ? ", \(val.overtime.shortFormatted) total overtime" : ", no overtime"
            return "  - \(name): \(val.count) task\(val.count == 1 ? "" : "s")\(otStr)"
        }.joined(separator: "\n")

        // Today's tasks
        let cal = Calendar.current
        let todayTasks = completed.filter { cal.isDateInToday($0.startTime) }
        let todayLines: String
        if todayTasks.isEmpty {
            todayLines = "  (none completed today)"
        } else {
            todayLines = todayTasks.map { task in
                let tag = task.tag?.name ?? "Untagged"
                let status = task.isOverTime ? "over" : "on time"
                return "  - \"\(task.label)\" [\(tag)] — \(status)"
            }.joined(separator: "\n")
        }

        // Recent 20 tasks with date labels
        let recent = completed.sorted { $0.startTime > $1.startTime }.prefix(20)
        let recentLines = recent.map { task in
            let tag = task.tag?.name ?? "Untagged"
            let day = relativeDay(for: task.startTime)
            let status = task.isOverTime
                ? "+\(max(0, (task.actualDuration ?? 0) - task.estimatedDuration).shortFormatted) over"
                : "on time"
            let notes = task.updates.map { $0.note }.joined(separator: "; ")
            let noteStr = notes.isEmpty ? "" : " | Note: \"\(notes)\""
            return "  - [\(day)] \"\(task.label)\" [\(tag)] — \(status)\(noteStr)"
        }.joined(separator: "\n")

        return """
        You are TaskMind — a sharp, direct productivity coach built into this app.
        You have full access to task history including dates. Today is \(today).

        Rules:
        - Under 80 words for most replies. Be specific, not generic.
        - When a data chart is shown to the user, give 1-2 sentence insight only — don't repeat the numbers.
        - You can add tasks to the user's schedule. When asked, respond with a confirmation message and embed: {{SCHEDULE:[{"label":"...","minutes":N,"tag":"..."}]}}
        - Tag names must match exactly from the Available tags list. If unsure, omit the tag field.
        - Speak like a coach, not a chatbot.

        FORMATTING:
        - Use **bold** for tag names, key numbers, and insights
        - Blank line between each distinct point
        - Use "——" on its own line before a key insight

        TASK DATA SUMMARY
        Total completed: \(completed.count) | On time: \(onTime) (\(onTimePct)%) | Over estimate: \(overtime)

        Today's completed tasks:
        \(todayLines)

        Breakdown by tag:
        \(tagLines)

        Recent tasks (newest first, up to 20):
        \(recentLines)

        Available tags: \(tagNames.isEmpty ? "none yet" : tagNames)
        """
    }

    // MARK: - Private

    private func buildSummaryPrompt(period: TimePeriodFilter, totalCompleted: Int, drains: [TaskEntry]) -> String {
        let periodLabel = period.rawValue.lowercased()
        var lines: [String] = []
        for task in drains {
            let overtime = (task.actualDuration ?? 0) - task.estimatedDuration
            let tag = task.tag?.name ?? "Untagged"
            let notes = task.updates.sorted { $0.createdAt < $1.createdAt }.map { $0.note }
            let noteText = notes.isEmpty ? "no note left" : notes.joined(separator: "; ")
            lines.append("- \"\(task.label)\" [\(tag)] ran \(overtime.shortFormatted) over. Note: \(noteText)")
        }
        let drainsText = lines.isEmpty ? "None" : lines.joined(separator: "\n")

        return """
        You are a friendly productivity coach giving a brief end-of-\(periodLabel) summary.

        Period: \(period.rawValue)
        Tasks completed: \(totalCompleted)
        Tasks that ran over estimate: \(drains.count)

        Overtime tasks and check-in notes:
        \(drainsText)

        Write a 2–3 sentence conversational summary. Start with "This \(periodLabel) you completed \(totalCompleted) task\(totalCompleted == 1 ? "" : "s")...". If there's a clear pattern in the notes, call it out directly. Keep it warm and specific. Plain prose only, no bullet points.
        """
    }

    private func callClaude(
        messages: [[String: String]],
        system: String? = nil,
        maxTokens: Int = 300
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        var body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": maxTokens,
            "messages": messages
        ]
        if let system { body["system"] = system }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "Anthropic", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API error \(http.statusCode): \(msg)"])
        }

        struct Response: Decodable {
            struct Block: Decodable { let text: String }
            let content: [Block]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.content.first?.text ?? ""
    }
}
