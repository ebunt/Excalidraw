import Foundation
import Testing
@testable import ExcalidrawZ

struct AISettingsStoreTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "LocalAISettingsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test
    @MainActor
    func localAISettingsStoreNormalizesDefaultBaseURL() {
        let store = LocalAISettingsStore(
            baseURLString: LocalAISettingsStore.defaultBaseURLString,
            userDefaults: makeIsolatedDefaults()
        )
        #expect(store.normalizedBaseURL?.absoluteString == "http://127.0.0.1:11434")
    }

    @Test
    @MainActor
    func localAISettingsStoreReturnsNilForEmptyURL() {
        let store = LocalAISettingsStore(baseURLString: "   ", userDefaults: makeIsolatedDefaults())
        #expect(store.normalizedBaseURL == nil)
    }

    @Test
    @MainActor
    func localAISettingsStoreNormalizesCustomURL() {
        let store = LocalAISettingsStore(
            baseURLString: "http://192.168.1.100:11434",
            userDefaults: makeIsolatedDefaults()
        )
        #expect(store.normalizedBaseURL?.absoluteString == "http://192.168.1.100:11434")
    }
}
