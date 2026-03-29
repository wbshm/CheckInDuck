import Foundation

enum TaskRecurrence: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .daily:
            return L10n.tr("task.recurrence.daily")
        case .weekly:
            return L10n.tr("task.recurrence.weekly")
        case .monthly:
            return L10n.tr("task.recurrence.monthly")
        case .yearly:
            return L10n.tr("task.recurrence.yearly")
        }
    }

    func summaryText(startDate: Date, calendar: Calendar) -> String {
        switch self {
        case .daily:
            return localizedTitle
        case .weekly:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            let weekday = formatter.string(from: startDate)
            return L10n.format("task.recurrence.summary.weekly", weekday)
        case .monthly:
            let day = calendar.component(.day, from: startDate)
            return L10n.format("task.recurrence.summary.monthly", day)
        case .yearly:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("MMMMd")
            let dateText = formatter.string(from: startDate)
            return L10n.format("task.recurrence.summary.yearly", dateText)
        }
    }

    func occurs(on date: Date, startDate: Date, calendar: Calendar) -> Bool {
        let targetDay = calendar.startOfDay(for: date)
        let anchorDay = calendar.startOfDay(for: startDate)
        guard targetDay >= anchorDay else { return false }

        switch self {
        case .daily:
            return true
        case .weekly:
            return calendar.component(.weekday, from: targetDay) == calendar.component(.weekday, from: anchorDay)
        case .monthly:
            return calendar.component(.day, from: targetDay) == calendar.component(.day, from: anchorDay)
        case .yearly:
            let targetComponents = calendar.dateComponents([.month, .day], from: targetDay)
            let anchorComponents = calendar.dateComponents([.month, .day], from: anchorDay)
            return targetComponents.month == anchorComponents.month &&
                targetComponents.day == anchorComponents.day
        }
    }

    func repeatingDateComponents(
        from date: Date,
        anchorDate: Date,
        calendar: Calendar,
        includeTime: Bool,
        second: Int? = nil
    ) -> DateComponents {
        var result = DateComponents()

        switch self {
        case .daily:
            break
        case .weekly:
            result.weekday = calendar.component(.weekday, from: anchorDate)
        case .monthly:
            result.day = calendar.component(.day, from: anchorDate)
        case .yearly:
            result.month = calendar.component(.month, from: anchorDate)
            result.day = calendar.component(.day, from: anchorDate)
        }

        if includeTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
            result.hour = timeComponents.hour
            result.minute = timeComponents.minute
        }

        if let second {
            result.second = second
        }
        return result
    }
}

struct HabitTask: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var appSelectionData: Data?
    var deadline: DailyDeadline
    var recurrence: TaskRecurrence
    var recurrenceAnchorDate: Date?
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
        recurrence: TaskRecurrence = .daily,
        recurrenceAnchorDate: Date? = nil,
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
        self.recurrence = recurrence
        self.recurrenceAnchorDate = recurrenceAnchorDate
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
        case recurrence
        case recurrenceAnchorDate
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
        recurrence = try container.decodeIfPresent(TaskRecurrence.self, forKey: .recurrence) ?? .daily
        recurrenceAnchorDate = try container.decodeIfPresent(Date.self, forKey: .recurrenceAnchorDate)
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
        try container.encode(recurrence, forKey: .recurrence)
        try container.encodeIfPresent(recurrenceAnchorDate, forKey: .recurrenceAnchorDate)
        try container.encode(usageThresholdSeconds, forKey: .usageThresholdSeconds)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(reminderConfig, forKey: .reminderConfig)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var effectiveRecurrenceStartDate: Date {
        recurrenceAnchorDate ?? createdAt
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        recurrence.occurs(on: date, startDate: effectiveRecurrenceStartDate, calendar: calendar)
    }

    func recurrenceSummary(calendar: Calendar = .current) -> String {
        recurrence.summaryText(startDate: effectiveRecurrenceStartDate, calendar: calendar)
    }

    func repeatingDateComponents(
        from date: Date,
        calendar: Calendar = .current,
        includeTime: Bool,
        second: Int? = nil
    ) -> DateComponents {
        recurrence.repeatingDateComponents(
            from: date,
            anchorDate: effectiveRecurrenceStartDate,
            calendar: calendar,
            includeTime: includeTime,
            second: second
        )
    }
}
