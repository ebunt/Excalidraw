import Foundation

@MainActor
final class LocalAISettingsStore: ObservableObject {
    @Published var baseURLString: String {
        didSet { save() }
    }

    init(baseURLString: String = Self.defaultBaseURLString) {
        if let stored = UserDefaults.standard.string(forKey: Self.baseURLDefaultsKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.baseURLString = stored
        } else {
            self.baseURLString = baseURLString
        }
    }

    var normalizedBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private func save() {
        UserDefaults.standard.set(baseURLString, forKey: Self.baseURLDefaultsKey)
    }

    private static let baseURLDefaultsKey = "ai.localHTTP.baseURL"
    static let defaultBaseURLString = "http://127.0.0.1:11434"
}
