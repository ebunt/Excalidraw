import Foundation
import Testing
@testable import ExcalidrawZ

struct AISettingsStoreTests {
    @Test
    @MainActor
    func localAISettingsStoreNormalizesDefaultBaseURL() {
        let suiteName = "LocalAISettingsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)

        let store = LocalAISettingsStore(baseURLString: LocalAISettingsStore.defaultBaseURLString)
        #expect(store.normalizedBaseURL?.absoluteString == "http://127.0.0.1:11434")
    }
}
