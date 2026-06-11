import Foundation

struct LocalAITestResponse: Decodable, Hashable {
    let echoedPrompt: String
    let documentTitle: String?
    let selectedTextCount: Int
}

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
                systemPrompt: "Return a JSON object that echoes the prompt and selected text count.",
                userPrompt: prompt,
                context: AIContext(
                    documentTitle: "Test Document",
                    selectedElementIDs: ["shape-1", "shape-2"],
                    selectedText: ["API Gateway", "Auth Service"],
                    sceneSummary: "A simple architecture diagram."
                ),
                format: .json(schemaName: "localAITestResponse")
            )

            let decoded = try JSONDecoder().decode(LocalAITestResponse.self, from: Data(response.text.utf8))
            resultText = "Prompt: \(decoded.echoedPrompt)\nDocument: \(decoded.documentTitle ?? "nil")\nSelected text count: \(decoded.selectedTextCount)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
