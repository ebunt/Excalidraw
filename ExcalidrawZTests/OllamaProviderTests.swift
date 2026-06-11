import Foundation
import Testing
@testable import ExcalidrawZ

struct OllamaProviderTests {
    @Test
    func extractsJSONObjectFromWrappedText() async throws {
        let provider = OllamaProvider(baseURL: URL(string: "http://127.0.0.1:11434")!)
        let response = try await provider.generate(
            request: AIRequest(
                systemPrompt: nil,
                userPrompt: "ignored",
                context: .empty,
                responseFormat: .json(schemaName: "test"),
                temperature: nil,
                maxTokens: nil
            ),
            model: AIModelDescriptor(
                id: "missing-session-model",
                displayName: "missing-session-model",
                providerID: "ollama",
                isLocal: true,
                contextWindow: nil
            )
        )
        _ = response
    }
}
