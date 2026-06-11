import Foundation

protocol AIProvider {
    var id: String { get }
    var displayName: String { get }

    func isAvailable() async -> Bool
    func availableModels() async throws -> [AIModelDescriptor]

    func generate(
        request: AIRequest,
        model: AIModelDescriptor?
    ) async throws -> AIResponse

    func stream(
        request: AIRequest,
        model: AIModelDescriptor?
    ) -> AsyncThrowingStream<String, Error>
}
