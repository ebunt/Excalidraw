import Foundation

struct AIRequest: Hashable {
    let systemPrompt: String?
    let userPrompt: String
    let context: AIContext
    let responseFormat: AIResponseFormat
    let temperature: Double?
    let maxTokens: Int?
}

enum AIResponseFormat: Hashable, Codable {
    case text
    case json(schemaName: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case schemaName
    }

    private enum Kind: String, Codable {
        case text
        case json
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)

        switch type {
        case .text:
            self = .text
        case .json:
            self = .json(
                schemaName: try container.decode(String.self, forKey: .schemaName)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text:
            try container.encode(Kind.text, forKey: .type)
        case .json(let schemaName):
            try container.encode(Kind.json, forKey: .type)
            try container.encode(schemaName, forKey: .schemaName)
        }
    }
}
