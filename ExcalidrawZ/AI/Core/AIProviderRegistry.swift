import Foundation

actor AIProviderRegistry {
    private var providers: [String: AIProvider] = [:]

    func register(_ provider: AIProvider) {
        providers[provider.id] = provider
    }

    func provider(id: String) -> AIProvider? {
        providers[id]
    }

    func allProviders() -> [AIProvider] {
        providers.values.sorted { $0.displayName < $1.displayName }
    }
}
