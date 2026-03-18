import Foundation

enum DailyTaskStatus: String, Codable {
    case pending
    case completed
    case missed

    var localizedTitle: String {
        switch self {
        case .pending:
            return L10n.tr("status.pending")
        case .completed:
            return L10n.tr("status.completed")
        case .missed:
            return L10n.tr("status.missed")
        }
    }
}

enum CompletionSource: String, Codable {
    case appUsageThreshold
    case manual
}

struct DailyRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var taskId: UUID
    var date: Date
    var status: DailyTaskStatus
    var completionSource: CompletionSource?
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        taskId: UUID,
        date: Date,
        status: DailyTaskStatus,
        completionSource: CompletionSource? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.date = date
        self.status = status
        self.completionSource = completionSource
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case taskId
        case taskID
        case date
        case status
        case completionSource
        case completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        taskId =
            try container.decodeIfPresent(UUID.self, forKey: .taskId) ??
            container.decode(UUID.self, forKey: .taskID)
        date = try container.decode(Date.self, forKey: .date)
        status = try container.decode(DailyTaskStatus.self, forKey: .status)
        completionSource = try container.decodeIfPresent(CompletionSource.self, forKey: .completionSource)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(date, forKey: .date)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(completionSource, forKey: .completionSource)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
    }
}
