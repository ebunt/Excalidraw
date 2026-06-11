import Foundation

@MainActor
final class AIContainer: ObservableObject {
    let settingsStore: AISettingsStore
    let localAISettingsStore: LocalAISettingsStore
    let registry: AIProviderRegistry
    let promptRegistry: PromptTemplateRegistry
    let aiService: AIService

    init(
        settingsStore: AISettingsStore = AISettingsStore(),
        localAISettingsStore: LocalAISettingsStore = LocalAISettingsStore(),
        registry: AIProviderRegistry = AIProviderRegistry(),
        promptRegistry: PromptTemplateRegistry = PromptTemplateRegistry()
    ) {
        self.settingsStore = settingsStore
        self.localAISettingsStore = localAISettingsStore
        self.registry = registry
        self.promptRegistry = promptRegistry
        self.aiService = AIService(
            registry: registry,
            settingsStore: settingsStore
        )

        Task {
            await registerProviders()
            await ensureDefaultSelection()
        }
    }

    func refreshProviders() {
        Task {
            await registerProviders()
        }
    }

    private func registerProviders() async {
        guard let baseURL = localAISettingsStore.normalizedBaseURL else { return }
        await registry.register(OllamaProvider(baseURL: baseURL))
        await registry.register(LocalHTTPProvider(baseURL: baseURL))
    }

    private func ensureDefaultSelection() async {
        if settingsStore.settings.selectedProviderID == nil {
            settingsStore.settings.selectedProviderID = "ollama"
        }
    }
}
