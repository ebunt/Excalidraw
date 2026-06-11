import Foundation
import Testing
@testable import ExcalidrawZ

// MARK: - URLProtocol mock (scoped to LocalHTTPProvider tests)

private final class LocalHTTPMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = LocalHTTPMockURLProtocol.requestHandler else {
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

private func makeLocalHTTPMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [LocalHTTPMockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

// MARK: - Tests

@Suite("LocalHTTPProvider", .serialized)
struct LocalHTTPProviderTests {
    let baseURL = URL(string: "http://127.0.0.1:8080")!

    private func makeProvider() -> LocalHTTPProvider {
        LocalHTTPProvider(baseURL: baseURL, session: makeLocalHTTPMockSession())
    }

    @Test("isAvailable returns true for 200 response")
    func isAvailableTrue() async {
        LocalHTTPMockURLProtocol.requestHandler = { request in
            (makeHTTPResponse(url: request.url!, statusCode: 200), Data())
        }
        let available = await makeProvider().isAvailable()
        #expect(available == true)
    }

    @Test("isAvailable returns false for 500 response")
    func isAvailableFalse() async {
        LocalHTTPMockURLProtocol.requestHandler = { request in
            (makeHTTPResponse(url: request.url!, statusCode: 500), Data())
        }
        let available = await makeProvider().isAvailable()
        #expect(available == false)
    }

    @Test("availableModels decodes model list correctly")
    func availableModels() async throws {
        let json = """
        {
            "models": [
                { "id": "my-model", "name": "My Model", "contextWindow": 4096 },
                { "id": "other-model", "name": "Other Model", "contextWindow": null }
            ]
        }
        """.data(using: .utf8)!

        LocalHTTPMockURLProtocol.requestHandler = { request in
            (makeHTTPResponse(url: request.url!, statusCode: 200), json)
        }

        let models = try await makeProvider().availableModels()
        #expect(models.count == 2)
        #expect(models[0].id == "my-model")
        #expect(models[0].displayName == "My Model")
        #expect(models[0].contextWindow == 4096)
        #expect(models[1].contextWindow == nil)
        #expect(models.allSatisfy { $0.providerID == "local-http" && $0.isLocal == true })
    }

    @Test("availableModels throws on non-2xx status")
    func availableModelsHTTPError() async {
        LocalHTTPMockURLProtocol.requestHandler = { request in
            (makeHTTPResponse(url: request.url!, statusCode: 503), Data("Service Unavailable".utf8))
        }
        do {
            _ = try await makeProvider().availableModels()
            Issue.record("Expected an error to be thrown")
        } catch let error as LocalHTTPProviderError {
            if case .httpError(let code, _) = error {
                #expect(code == 503)
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("generate decodes response text")
    func generate() async throws {
        let responseJSON = """
        { "text": "Hello world", "finishReason": "stop", "model": "my-model" }
        """.data(using: .utf8)!

        LocalHTTPMockURLProtocol.requestHandler = { request in
            (makeHTTPResponse(url: request.url!, statusCode: 200), responseJSON)
        }

        let provider = makeProvider()
        let request = AIRequest(
            systemPrompt: nil,
            userPrompt: "Say hello",
            context: .empty,
            responseFormat: .text,
            temperature: 0.5,
            maxTokens: 256
        )
        let model = AIModelDescriptor(
            id: "my-model",
            displayName: "My Model",
            providerID: "local-http",
            isLocal: true,
            contextWindow: nil
        )
        let response = try await provider.generate(request: request, model: model)

        #expect(response.text == "Hello world")
        #expect(response.finishReason == "stop")
        #expect(response.modelID == "my-model")
    }

    @Test("generate sends POST with correct content-type")
    func generateSendsPost() async throws {
        let responseJSON = """
        { "text": "ok", "finishReason": "stop", "model": "m" }
        """.data(using: .utf8)!

        var capturedRequest: URLRequest?
        LocalHTTPMockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (makeHTTPResponse(url: request.url!, statusCode: 200), responseJSON)
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
}
