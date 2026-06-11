import Testing
@testable import ExcalidrawZ

struct AIResponseFormatTests {
    @Test
    func jsonFormatRoundTrips() throws {
        let value = AIResponseFormat.json(schemaName: "diagramDraftV1")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AIResponseFormat.self, from: data)
        #expect(decoded == value)
    }

    @Test
    func textFormatRoundTrips() throws {
        let value = AIResponseFormat.text
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AIResponseFormat.self, from: data)
        #expect(decoded == value)
    }
}
