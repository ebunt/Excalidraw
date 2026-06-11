import Foundation

struct AIModelDescriptor: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let providerID: String
    let isLocal: Bool
    let contextWindow: Int?
}
