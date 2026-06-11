import Foundation

struct AISettings: Codable, Hashable {
    var selectedProviderID: String?
    var selectedModelID: String?
    var maxTokens: Int = 1024
    var temperature: Double = 0.2
    var onDeviceOnly: Bool = true
}
