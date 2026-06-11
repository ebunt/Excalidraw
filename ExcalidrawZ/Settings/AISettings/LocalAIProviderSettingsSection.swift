import SwiftUI

struct LocalAIProviderSettingsSection: View {
    @ObservedObject var aiContainer: AIContainer
    @StateObject private var viewModel: AIProviderSelectionViewModel

    init(aiContainer: AIContainer) {
        self.aiContainer = aiContainer
        _viewModel = StateObject(wrappedValue: AIProviderSelectionViewModel(container: aiContainer))
    }

    var body: some View {
        Section {
            Toggle(isOn: $aiContainer.settingsStore.settings.onDeviceOnly) {
                Text("On-device only")
            }

            Picker("AI provider", selection: $aiContainer.settingsStore.settings.selectedProviderID.toNonOptional(defaultValue: "ollama")) {
                Text("Ollama")
                    .tag("ollama")
                Text("Local HTTP")
                    .tag("local-http")
            }
            .onChange(of: aiContainer.settingsStore.settings.selectedProviderID) { _, _ in
                Task { await viewModel.refresh() }
            }

            TextField("Server URL", text: $aiContainer.localAISettingsStore.baseURLString)
#if os(macOS)
                .textFieldStyle(.roundedBorder)
#endif
                .onSubmit {
                    aiContainer.refreshProviders()
                    Task { await viewModel.refresh() }
                }

            Stepper(value: $aiContainer.settingsStore.settings.maxTokens, in: 128...8192, step: 128) {
                Text("Max tokens: \(aiContainer.settingsStore.settings.maxTokens)")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Temperature: \(aiContainer.settingsStore.settings.temperature.formatted(.number.precision(.fractionLength(0...2))))")
                Slider(value: $aiContainer.settingsStore.settings.temperature, in: 0...1)
            }

            Picker("Model", selection: $aiContainer.settingsStore.settings.selectedModelID.toNonOptional(defaultValue: "")) {
                if viewModel.models.isEmpty {
                    Text("No models available")
                        .tag("")
                } else {
                    ForEach(viewModel.models) { model in
                        Text(model.displayName)
                            .tag(model.id)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Refresh models") {
                    aiContainer.refreshProviders()
                    Task { await viewModel.refresh() }
                }

                if viewModel.isCheckingAvailability {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.isAvailable ? .secondary : .red)
            }
        } header: {
            Text("Local AI provider")
        } footer: {
            Text("Use Ollama directly or provide a custom local server exposing /models and /generate endpoints.")
        }
        .task {
            await viewModel.refresh()
        }
    }
}

private extension Binding where Value == String? {
    func toNonOptional(defaultValue: String) -> Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? defaultValue },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
