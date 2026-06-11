import Foundation

@MainActor
final class AISettingsStore: ObservableObject {
    @Published var settings: AISettings {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AISettings.self, from: data) {
            settings = decoded
        } else {
            settings = AISettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static let storageKey = "ai.settings"
}
