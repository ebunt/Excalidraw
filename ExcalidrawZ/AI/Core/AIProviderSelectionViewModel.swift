import Foundation

@MainActor
final class AIProviderSelectionViewModel: ObservableObject {
    @Published private(set) var models: [AIModelDescriptor] = []
    @Published private(set) var isCheckingAvailability = false
    @Published private(set) var isAvailable = false
    @Published private(set) var statusMessage: String?

    private let container: AIContainer

    init(container: AIContainer) {
        self.container = container
    }

    func refresh() async {
        isCheckingAvailability = true
        defer { isCheckingAvailability = false }

        container.refreshProviders()

        guard let provider = await container.registry.provider(id: "local-http") else {
            models = []
            isAvailable = false
            statusMessage = "Local HTTP provider is not configured."
            return
        }

        do {
            let available = await provider.isAvailable()
            isAvailable = available

            if available {
                let loadedModels = try await provider.availableModels()
                models = loadedModels
                statusMessage = loadedModels.isEmpty
                    ? "Connected, but the provider reported no local models."
                    : "Connected to local AI provider."

                if container.settingsStore.settings.selectedModelID == nil,
                   let firstModel = loadedModels.first {
                    container.settingsStore.settings.selectedModelID = firstModel.id
                }
            } else {
                models = []
                statusMessage = "Unable to reach the local AI server."
            }
        } catch {
            models = []
            isAvailable = false
            statusMessage = error.localizedDescription
        }
    }
}
