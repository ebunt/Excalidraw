import Foundation

enum AIServiceError: LocalizedError {
    case noProviderSelected
    case selectedProviderUnavailable(String)
    case selectedModelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .noProviderSelected:
            return "No AI provider selected."
        case .selectedProviderUnavailable(let providerID):
            return "The selected AI provider is unavailable: \(providerID)"
        case .selectedModelUnavailable(let modelID):
            return "The selected AI model is unavailable: \(modelID)"
        }
    }
}

@MainActor
final class AIService: ObservableObject {
    @Published var isBusy = false
    @Published var lastError: String?

    private let registry: AIProviderRegistry
    private let settingsStore: AISettingsStore

    init(
        registry: AIProviderRegistry,
        settingsStore: AISettingsStore
    ) {
        self.registry = registry
        self.settingsStore = settingsStore
    }

    func generate(
        systemPrompt: String?,
        userPrompt: String,
        context: AIContext,
        format: AIResponseFormat
    ) async throws -> AIResponse {
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        let settings = settingsStore.settings

        guard let providerID = settings.selectedProviderID else {
            throw AIServiceError.noProviderSelected
        }

        guard let provider = await registry.provider(id: providerID) else {
            throw AIServiceError.selectedProviderUnavailable(providerID)
        }

        let models = try await provider.availableModels()
        let selectedModel: AIModelDescriptor?

        if let selectedModelID = settings.selectedModelID {
            guard let model = models.first(where: { $0.id == selectedModelID }) else {
                throw AIServiceError.selectedModelUnavailable(selectedModelID)
            }
            selectedModel = model
        } else {
            selectedModel = nil
        }

        let request = AIRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            context: context,
            responseFormat: format,
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )

        do {
            return try await provider.generate(request: request, model: selectedModel)
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func stream(
        systemPrompt: String?,
        userPrompt: String,
        context: AIContext,
        format: AIResponseFormat
    ) async throws -> AsyncThrowingStream<String, Error> {
        let settings = settingsStore.settings

        guard let providerID = settings.selectedProviderID else {
            throw AIServiceError.noProviderSelected
        }

        guard let provider = await registry.provider(id: providerID) else {
            throw AIServiceError.selectedProviderUnavailable(providerID)
        }

        let models = try await provider.availableModels()
        let selectedModel: AIModelDescriptor?

        if let selectedModelID = settings.selectedModelID {
            guard let model = models.first(where: { $0.id == selectedModelID }) else {
                throw AIServiceError.selectedModelUnavailable(selectedModelID)
            }
            selectedModel = model
        } else {
            selectedModel = nil
        }

        let request = AIRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            context: context,
            responseFormat: format,
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )

        return provider.stream(request: request, model: selectedModel)
    }
}
