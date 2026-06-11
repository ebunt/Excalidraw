import Foundation

@MainActor
final class LocalAITestViewModel: ObservableObject {
    @Published var prompt: String = "Summarize the current selection."
    @Published private(set) var resultText: String?
    @Published private(set) var isRunning = false
    @Published private(set) var errorMessage: String?

    private let aiService: AIService
    private let contextBuilder: CanvasAIContextBuilder?

    init(aiService: AIService, contextBuilder: CanvasAIContextBuilder? = nil) {
        self.aiService = aiService
        self.contextBuilder = contextBuilder
    }

    func run() async {
        isRunning = true
        errorMessage = nil
        resultText = nil
        defer { isRunning = false }

        do {
            let context: AIContext
            if let contextBuilder {
                context = await contextBuilder.build()
            } else {
                context = .empty
            }

            let response = try await aiService.generate(
                systemPrompt: "Summarize the given context concisely. If asked for JSON, return valid JSON only.",
                userPrompt: prompt,
                context: context,
                format: .text
            )
            resultText = response.text
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
