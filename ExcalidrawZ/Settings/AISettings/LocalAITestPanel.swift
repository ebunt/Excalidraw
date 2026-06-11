import SwiftUI

struct LocalAITestPanel: View {
    @ObservedObject var aiContainer: AIContainer
    @StateObject private var viewModel: LocalAITestViewModel

    init(aiContainer: AIContainer) {
        self.aiContainer = aiContainer
        _viewModel = StateObject(
            wrappedValue: LocalAITestViewModel(
                aiService: aiContainer.aiService,
                contextBuilder: CanvasAIContextBuilder()
            )
        )
    }

    var body: some View {
        Section {
            TextField("Test prompt", text: $viewModel.prompt, axis: .vertical)
                .lineLimit(2...5)

            Button {
                Task { await viewModel.run() }
            } label: {
                if viewModel.isRunning {
                    ProgressView()
                } else {
                    Text("Run local AI test")
                }
            }
            .disabled(viewModel.isRunning)

            if let resultText = viewModel.resultText {
                Text(resultText)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Local AI test")
        } footer: {
            Text("Sends a request through AIService using the live canvas state (selected elements, scene summary). Select elements on the canvas before running to include them in context.")
        }
    }
}
