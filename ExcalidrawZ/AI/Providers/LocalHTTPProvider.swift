import Foundation

struct LocalHTTPProvider: AIProvider {
    let id = "local-http"
    let displayName = "Local HTTP"

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func isAvailable() async -> Bool {
        do {
            let url = endpointURL(path: "models")
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    func availableModels() async throws -> [AIModelDescriptor] {
        let url = endpointURL(path: "models")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)

        let payload = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return payload.models.map {
            AIModelDescriptor(
                id: $0.id,
                displayName: $0.name,
                providerID: id,
                isLocal: true,
                contextWindow: $0.contextWindow
            )
        }
    }

    func generate(
        request: AIRequest,
        model: AIModelDescriptor?
    ) async throws -> AIResponse {
        let url = endpointURL(path: "generate")
        let body = LocalGenerateRequest(
            model: model?.id,
            systemPrompt: request.systemPrompt,
            prompt: buildPrompt(from: request),
            responseFormat: request.responseFormat,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, data: data)

        let payload = try JSONDecoder().decode(LocalGenerateResponse.self, from: data)
        return AIResponse(
            text: payload.text,
            finishReason: payload.finishReason,
            modelID: payload.model
        )
    }

    func stream(
        request: AIRequest,
        model: AIModelDescriptor?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LocalHTTPProviderError.streamingNotImplemented)
        }
    }

    private func endpointURL(path: String) -> URL {
        var value = baseURL
        if value.absoluteString.hasSuffix("/") {
            value.deleteLastPathComponent()
        }
        return value.appendingPathComponent(path)
    }

    private func buildPrompt(from request: AIRequest) -> String {
        var sections: [String] = []

        if let title = request.context.documentTitle, !title.isEmpty {
            sections.append("Document title:\n\(title)")
        }

        if let sceneSummary = request.context.sceneSummary, !sceneSummary.isEmpty {
            sections.append("Scene summary:\n\(sceneSummary)")
        }

        if !request.context.selectedText.isEmpty {
            sections.append("Selected text:\n\(request.context.selectedText.joined(separator: "\n"))")
        }

        if !request.context.selectedElementIDs.isEmpty {
            sections.append("Selected element IDs:\n\(request.context.selectedElementIDs.joined(separator: ", "))")
        }

        sections.append("User request:\n\(request.userPrompt)")
        return sections.joined(separator: "\n\n")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalHTTPProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw LocalHTTPProviderError.httpError(
                statusCode: httpResponse.statusCode,
                body: message
            )
        }
    }
}

enum LocalHTTPProviderError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case streamingNotImplemented

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The local AI server returned an invalid response."
        case .httpError(let statusCode, let body):
            if let body, !body.isEmpty {
                return "Local AI server request failed with status \(statusCode): \(body)"
            }
            return "Local AI server request failed with status \(statusCode)."
        case .streamingNotImplemented:
            return "Streaming is not implemented for the Local HTTP provider yet."
        }
    }
}

private struct ModelListResponse: Decodable {
    let models: [ModelListItem]
}

private struct ModelListItem: Decodable {
    let id: String
    let name: String
    let contextWindow: Int?
}

private struct LocalGenerateRequest: Encodable {
    let model: String?
    let systemPrompt: String?
    let prompt: String
    let responseFormat: AIResponseFormat
    let temperature: Double?
    let maxTokens: Int?
}

private struct LocalGenerateResponse: Decodable {
    let text: String
    let finishReason: String?
    let model: String?
}
