import SwiftUI

extension AISettingsView {
    @ViewBuilder
    var selectedEnabledTabContent: some View {
        switch selectedTab {
            case .usage:
                Section {
                    activityBody
                } header: {
                    VStack(spacing: 10) {
                        usageHeader
                            .textCase(nil)

                        activityHeader
                    }
                }
            case .settings:
                Section {
                    defaultModelPicker
                } header: {
                    settingsHeader
                        .textCase(nil)
                }

                localProviderSection

                if let aiContainer {
                    LocalAITestPanel(aiContainer: aiContainer)
                }

                Section {
                    aiAccountRows
                } header: {
                    aiAccountHeader
                        .textCase(nil)
                }
            case .information:
                informationSection
        }
    }
}
