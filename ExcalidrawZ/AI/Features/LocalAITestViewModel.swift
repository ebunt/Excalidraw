import Foundation

@MainActor
final class LocalAITestViewModel: ObservableObject {
    @Published var prompt: String = "Summarize the current selection."
    @Published private(set) var resultText: String?
    @Published private(set) var isRunning = false
    @Published private(set) var errorMessage: String?

    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    func run() async {
        isRunning = true
        errorMessage = nil
        resultText = nil
        defer { isRunning = false }

        do {
            let response = try await aiService.generate(
                systemPrompt: "Summarize the given context concisely. If asked for JSON, return valid JSON only.",
                userPrompt: prompt,
                context: AIContext(
                    documentTitle: "Test Document",
                    selectedElementIDs: ["shape-1", "shape-2"],
                    selectedText: ["API Gateway", "Auth Service"],
                    sceneSummary: "A simple architecture diagram."
                ),
                format: .text
            )
            resultText = response.text
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
