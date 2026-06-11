import Foundation

/// A provider that talks directly to a running Ollama server.
///
/// Endpoints used:
/// - `GET  /api/tags`     – list installed models
/// - `POST /api/generate` – generate a completion (non-streaming)
struct OllamaProvider: AIProvider {
    let id = "ollama"
    let displayName = "Ollama"

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func isAvailable() async -> Bool {
        do {
            let url = endpointURL(path: "api/tags")
            let (_, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    func availableModels() async throws -> [AIModelDescriptor] {
        let url = endpointURL(path: "api/tags")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)

        let payload = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return payload.models.map {
            AIModelDescriptor(
                id: $0.name,
                displayName: $0.name,
                providerID: id,
                isLocal: true,
                contextWindow: nil
            )
        }
    }

    func generate(
        request: AIRequest,
        model: AIModelDescriptor?
    ) async throws -> AIResponse {
        let url = endpointURL(path: "api/generate")
        let body = OllamaGenerateRequest(
            model: model?.id ?? "llama2",
            prompt: buildPrompt(from: request),
            system: request.systemPrompt,
            stream: false,
            options: OllamaOptions(
                temperature: request.temperature,
                num_predict: request.maxTokens
            )
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, data: data)

        let payload = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        return AIResponse(
            text: payload.response,
            finishReason: payload.done ? payload.done_reason ?? "stop" : nil,
            modelID: payload.model
        )
    }

    func stream(
        request: AIRequest,
        model: AIModelDescriptor?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: OllamaProviderError.streamingNotImplemented)
        }
    }

    private func endpointURL(path: String) -> URL {
        var base = baseURL
        if base.absoluteString.hasSuffix("/") {
            base.deleteLastPathComponent()
        }
        return base.appendingPathComponent(path)
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
            throw OllamaProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw OllamaProviderError.httpError(statusCode: httpResponse.statusCode, body: message)
        }
    }
}

enum OllamaProviderError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case streamingNotImplemented

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ollama returned an invalid response."
        case .httpError(let code, let body):
            if let body, !body.isEmpty {
                return "Ollama request failed with status \(code): \(body)"
            }
            return "Ollama request failed with status \(code)."
        case .streamingNotImplemented:
            return "Streaming is not implemented for the Ollama provider yet."
        }
    }
}

// MARK: - Codable payload types

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

private struct OllamaModel: Decodable {
    let name: String
}

private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool
    let options: OllamaOptions
}

private struct OllamaOptions: Encodable {
    let temperature: Double?
    let num_predict: Int?
}

private struct OllamaGenerateResponse: Decodable {
    let model: String
    let response: String
    let done: Bool
    let done_reason: String?
}
