import Foundation

struct AIContext: Codable, Hashable {
    let documentTitle: String?
    let selectedElementIDs: [String]
    let selectedText: [String]
    let sceneSummary: String?

    static let empty = AIContext(
        documentTitle: nil,
        selectedElementIDs: [],
        selectedText: [],
        sceneSummary: nil
    )
}
