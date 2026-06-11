import Foundation

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
            let (_, response) = try await session.data(from: endpointURL(path: "/api/tags"))
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200..<300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    func availableModels() async throws -> [AIModelDescriptor] {
        let (data, response) = try await session.data(from: endpointURL(path: "/api/tags"))
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
        let modelName = model?.id ?? ""
        guard !modelName.isEmpty else {
            throw OllamaProviderError.noModelSelected
        }

        let body = OllamaGenerateRequest(
            model: modelName,
            prompt: buildPrompt(from: request),
            system: request.systemPrompt,
            stream: false,
            options: OllamaGenerateOptions(
                temperature: request.temperature,
                numPredict: request.maxTokens
            )
        )

        var urlRequest = URLRequest(url: endpointURL(path: "/api/generate"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, data: data)

        let payload = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        return AIResponse(
            text: sanitizeResponseText(payload.response),
            finishReason: payload.done ? "stop" : nil,
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
        let trimmedBase = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        return URL(string: trimmedBase + path) ?? baseURL
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

        switch request.responseFormat {
        case .text:
            break
        case .json(let schemaName):
            sections.append("Return JSON only. Schema name: \(schemaName)")
        }

        sections.append("User request:\n\(request.userPrompt)")
        return sections.joined(separator: "\n\n")
    }

    private func sanitizeResponseText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.first == "{" || trimmed.first == "[" {
            return trimmed
        }

        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        if let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") {
            return String(trimmed[start...end])
        }

        return trimmed
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw OllamaProviderError.httpError(
                statusCode: httpResponse.statusCode,
                body: message
            )
        }
    }
}

enum OllamaProviderError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case noModelSelected
    case streamingNotImplemented

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Ollama server returned an invalid response."
        case .httpError(let statusCode, let body):
            if let body, !body.isEmpty {
                return "Ollama request failed with status \(statusCode): \(body)"
            }
            return "Ollama request failed with status \(statusCode)."
        case .noModelSelected:
            return "No Ollama model selected."
        case .streamingNotImplemented:
            return "Streaming is not implemented for the Ollama provider yet."
        }
    }
}

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
    let options: OllamaGenerateOptions?
}

private struct OllamaGenerateOptions: Encodable {
    let temperature: Double?
    let numPredict: Int?

    enum CodingKeys: String, CodingKey {
        case temperature
        case numPredict = "num_predict"
    }
}

private struct OllamaGenerateResponse: Decodable {
    let model: String?
    let response: String
    let done: Bool
}
