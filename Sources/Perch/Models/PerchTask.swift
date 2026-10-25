import Foundation

struct PerchTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date
    var completedAt: Date?
    /// When to send a reminder notification, if one is set.
    var remindAt: Date?
    /// Parked in the Future section: jotted down to remember, not for now.
    var isFuture: Bool

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.createdAt = Date()
        self.completedAt = nil
        self.remindAt = nil
        self.isFuture = false
    }

    // Spelled out so tasks saved before `isFuture` existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        isDone = try c.decode(Bool.self, forKey: .isDone)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        remindAt = try c.decodeIfPresent(Date.self, forKey: .remindAt)
        isFuture = try c.decodeIfPresent(Bool.self, forKey: .isFuture) ?? false
    }
}
