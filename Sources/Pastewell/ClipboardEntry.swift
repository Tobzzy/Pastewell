import Foundation

struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var copiedAt: Date
    var isPinned: Bool
    var sourceAppName: String?
    var sourceBundleIdentifier: String?

    init(
        id: UUID = UUID(),
        text: String,
        copiedAt: Date = Date(),
        isPinned: Bool = false,
        sourceAppName: String? = nil,
        sourceBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.sourceAppName = sourceAppName
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }
}
