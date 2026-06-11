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

        let providerID = container.settingsStore.settings.selectedProviderID ?? "ollama"
        guard let provider = await container.registry.provider(id: providerID) else {
            models = []
            isAvailable = false
            statusMessage = "Selected AI provider is not configured."
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
                    : "Connected to \(provider.displayName)."

                if let selectedModelID = container.settingsStore.settings.selectedModelID,
                   loadedModels.contains(where: { $0.id == selectedModelID }) {
                    return
                }

                container.settingsStore.settings.selectedModelID = loadedModels.first?.id
            } else {
                models = []
                statusMessage = "Unable to reach \(provider.displayName)."
            }
        } catch {
            models = []
            isAvailable = false
            statusMessage = error.localizedDescription
        }
    }
}
