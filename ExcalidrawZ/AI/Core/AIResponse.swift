import Foundation

struct AIResponse: Hashable {
    let text: String
    let finishReason: String?
    let modelID: String?
}
