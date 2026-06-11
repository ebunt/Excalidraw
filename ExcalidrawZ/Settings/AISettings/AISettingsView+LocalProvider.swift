import SwiftUI

extension AISettingsView {
    @ViewBuilder
    var localProviderSection: some View {
        if let aiContainer {
            LocalAIProviderSettingsSection(aiContainer: aiContainer)
        }
    }
}
