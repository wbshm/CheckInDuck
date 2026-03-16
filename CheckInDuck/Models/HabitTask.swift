import Foundation

struct HabitTask: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var appSelectionData: Data?
    var deadline: DailyDeadline
    var usageThresholdSeconds: Int
    var isEnabled: Bool
    var reminderConfig: ReminderConfig
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        appSelectionData: Data? = nil,
        deadline: DailyDeadline,
        usageThresholdSeconds: Int = 180,
        isEnabled: Bool = true,
        reminderConfig: ReminderConfig = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.appSelectionData = appSelectionData
        self.deadline = deadline
        self.usageThresholdSeconds = usageThresholdSeconds
        self.isEnabled = isEnabled
        self.reminderConfig = reminderConfig
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case appSelectionData
        case familyActivitySelectionData
        case deadline
        case usageThresholdSeconds
        case isEnabled
        case reminderConfig
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        appSelectionData =
            try container.decodeIfPresent(Data.self, forKey: .appSelectionData) ??
            container.decodeIfPresent(Data.self, forKey: .familyActivitySelectionData)
        deadline = try container.decode(DailyDeadline.self, forKey: .deadline)
        usageThresholdSeconds = try container.decode(Int.self, forKey: .usageThresholdSeconds)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        reminderConfig = try container.decode(ReminderConfig.self, forKey: .reminderConfig)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(appSelectionData, forKey: .appSelectionData)
        try container.encode(deadline, forKey: .deadline)
        try container.encode(usageThresholdSeconds, forKey: .usageThresholdSeconds)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(reminderConfig, forKey: .reminderConfig)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
