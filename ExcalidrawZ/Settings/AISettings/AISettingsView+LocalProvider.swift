import SwiftUI

extension AISettingsView {
    @ViewBuilder
    var localProviderSection: some View {
        LocalAIProviderSettingsSection(aiContainer: aiContainer)
    }
}
