import Foundation
import Testing
@testable import ExcalidrawZ

// MARK: - URLProtocol mock (scoped to OllamaProvider tests)

private final class OllamaMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = OllamaMockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeOllamaMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [OllamaMockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeOllamaHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

// MARK: - Tests

@Suite("OllamaProvider", .serialized)
struct OllamaProviderTests {
    let baseURL = URL(string: "http://127.0.0.1:11434")!

    private func makeProvider() -> OllamaProvider {
        OllamaProvider(baseURL: baseURL, session: makeOllamaMockSession())
    }

    @Test("isAvailable returns true for 200 response on /api/tags")
    func isAvailableTrue() async {
        OllamaMockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/api/tags")
            return (makeOllamaHTTPResponse(url: request.url!, statusCode: 200), Data())
        }
        let available = await makeProvider().isAvailable()
        #expect(available == true)
    }

    @Test("isAvailable returns false for connection error")
    func isAvailableFalse() async {
        OllamaMockURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }
        let available = await makeProvider().isAvailable()
        #expect(available == false)
    }

    @Test("availableModels decodes Ollama tags response")
    func availableModels() async throws {
        let json = """
        {
            "models": [
                { "name": "llama2:latest" },
                { "name": "mistral:7b" }
            ]
        }
        """.data(using: .utf8)!

        OllamaMockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/api/tags")
            return (makeOllamaHTTPResponse(url: request.url!, statusCode: 200), json)
        }

        let models = try await makeProvider().availableModels()
        #expect(models.count == 2)
        #expect(models[0].id == "llama2:latest")
        #expect(models[0].displayName == "llama2:latest")
        #expect(models[1].id == "mistral:7b")
        #expect(models.allSatisfy { $0.providerID == "ollama" && $0.isLocal == true })
    }

    @Test("availableModels throws on HTTP error")
    func availableModelsHTTPError() async {
        OllamaMockURLProtocol.requestHandler = { request in
            (makeOllamaHTTPResponse(url: request.url!, statusCode: 404), Data("Not Found".utf8))
        }

        do {
            _ = try await makeProvider().availableModels()
            Issue.record("Expected an error to be thrown")
        } catch let error as OllamaProviderError {
            if case .httpError(let code, _) = error {
                #expect(code == 404)
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("generate decodes Ollama generate response")
    func generate() async throws {
        let responseJSON = """
        {
            "model": "llama2:latest",
            "response": "Hello from Ollama",
            "done": true,
            "done_reason": "stop"
        }
        """.data(using: .utf8)!

        OllamaMockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/api/generate")
            return (makeOllamaHTTPResponse(url: request.url!, statusCode: 200), responseJSON)
        }

        let provider = makeProvider()
        let request = AIRequest(
            systemPrompt: "You are helpful.",
            userPrompt: "Say hello",
            context: .empty,
            responseFormat: .text,
            temperature: 0.7,
            maxTokens: 512
        )
        let model = AIModelDescriptor(
            id: "llama2:latest",
            displayName: "llama2:latest",
            providerID: "ollama",
            isLocal: true,
            contextWindow: nil
        )
        let response = try await provider.generate(request: request, model: model)

        #expect(response.text == "Hello from Ollama")
        #expect(response.finishReason == "stop")
        #expect(response.modelID == "llama2:latest")
    }

    @Test("generate sends POST with correct content-type")
    func generateSendsPost() async throws {
        let responseJSON = """
        { "model": "llama2", "response": "ok", "done": true, "done_reason": "stop" }
        """.data(using: .utf8)!

        var capturedRequest: URLRequest?
        OllamaMockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (makeOllamaHTTPResponse(url: request.url!, statusCode: 200), responseJSON)
        }

        let request = AIRequest(
            systemPrompt: nil,
            userPrompt: "test",
            context: .empty,
            responseFormat: .text,
            temperature: nil,
            maxTokens: nil
        )
        _ = try await makeProvider().generate(request: request, model: nil)

        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("generate includes system prompt in request body")
    func generateIncludesSystemPrompt() async throws {
        let responseJSON = """
        { "model": "llama2", "response": "ok", "done": true, "done_reason": "stop" }
        """.data(using: .utf8)!

        var capturedBodyData: Data?
        OllamaMockURLProtocol.requestHandler = { request in
            capturedBodyData = request.httpBody
            return (makeOllamaHTTPResponse(url: request.url!, statusCode: 200), responseJSON)
        }

        let request = AIRequest(
            systemPrompt: "Be concise.",
            userPrompt: "Summarize this.",
            context: .empty,
            responseFormat: .text,
            temperature: nil,
            maxTokens: nil
        )
        _ = try await makeProvider().generate(request: request, model: nil)

        let body = try #require(capturedBodyData)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["system"] as? String == "Be concise.")
    }

    @Test("stream returns streamingNotImplemented error immediately")
    func streamNotImplemented() async {
        var errorThrown: Error?
        let provider = makeProvider()
        let request = AIRequest(
            systemPrompt: nil,
            userPrompt: "test",
            context: .empty,
            responseFormat: .text,
            temperature: nil,
            maxTokens: nil
        )
        let stream = provider.stream(request: request, model: nil)
        do {
            for try await _ in stream { }
        } catch {
            errorThrown = error
        }
        #expect(errorThrown != nil)
        if let ollamaError = errorThrown as? OllamaProviderError,
           case .streamingNotImplemented = ollamaError {
        } else {
            Issue.record("Expected OllamaProviderError.streamingNotImplemented, got \(String(describing: errorThrown))")
        }
    }
}
