import Foundation

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

    func generateSummary(period: TimePeriodFilter, tasks: [TaskEntry]) async {
        let drains = tasks
            .filter { $0.isOverTime }
            .sorted {
                let a = ($0.actualDuration ?? 0) - $0.estimatedDuration
                let b = ($1.actualDuration ?? 0) - $1.estimatedDuration
                return a > b
            }

        let totalCompleted = tasks.filter { $0.endTime != nil }.count
        let prompt = buildPrompt(period: period, totalCompleted: totalCompleted, drains: drains)

        await MainActor.run {
            isLoading = true
            errorMessage = ""
            summary = ""
        }

        do {
            let result = try await callClaude(prompt: prompt)
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

    // MARK: - Private

    private func buildPrompt(period: TimePeriodFilter, totalCompleted: Int, drains: [TaskEntry]) -> String {
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

        Write a 2–3 sentence conversational summary. Start with "This \(periodLabel) you completed \(totalCompleted) task\(totalCompleted == 1 ? "" : "s")...". If there's a clear pattern in the notes (e.g. interruptions, unclear scope, context switching), call it out directly. Keep it warm and specific, not generic. Do not use bullet points or headers — plain prose only.
        """
    }

    private func callClaude(prompt: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 300,
            "messages": [["role": "user", "content": prompt]]
        ]
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
