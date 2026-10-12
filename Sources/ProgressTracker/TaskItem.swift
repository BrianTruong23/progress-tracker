import Foundation

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: Self { self }
    var rank: Int { self == .high ? 2 : self == .medium ? 1 : 0 }
}

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var project: String
    var priority: TaskPriority
    var dueDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        project: String = "Inbox",
        priority: TaskPriority = .medium,
        dueDate: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.project = project
        self.priority = priority
        self.dueDate = dueDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, createdAt, project, priority, dueDate
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        isCompleted = try values.decode(Bool.self, forKey: .isCompleted)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        project = try values.decodeIfPresent(String.self, forKey: .project) ?? "Inbox"
        priority = try values.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        dueDate = try values.decodeIfPresent(Date.self, forKey: .dueDate) ?? createdAt
    }
}
