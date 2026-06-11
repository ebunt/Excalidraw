import Foundation

enum AIFeature {
    case labelSuggestions
    case diagramGeneration
    case selectionSummary
}

struct PromptTemplateRegistry {
    func systemPrompt(for feature: AIFeature) -> String {
        switch feature {
        case .labelSuggestions:
            return "You improve labels for diagram elements. Return concise results only."
        case .diagramGeneration:
            return "You generate diagram drafts as strict JSON only."
        case .selectionSummary:
            return "You summarize selected diagram content clearly and concisely."
        }
    }
}
