import Foundation

protocol AppUsageCompletionEventReading {
    func consumeCompletedTaskIDs() -> [UUID]
}

protocol AppUsageCompletionEventWriting {
    func appendCompletedTaskID(_ taskID: UUID, occurredAt: Date)
}

struct AppUsageCompletionEventDebugSnapshot {
    let usesAppGroupDefaults: Bool
    let totalEventCount: Int
    let todayEventCount: Int
    let lastEventAt: Date?
    let lastIntervalStartTaskID: String?
    let lastIntervalStartAt: Date?
    let lastThresholdTaskID: String?
    let lastThresholdAt: Date?
}

protocol AppUsageCompletionEventDebugging {
    func debugSnapshot(now: Date) -> AppUsageCompletionEventDebugSnapshot
}

final class AppUsageCompletionEventStore: AppUsageCompletionEventReading, AppUsageCompletionEventWriting {
    private let defaults: KeyValueStoring
    private let calendar: Calendar
    private let usesAppGroupDefaults: Bool
    private let storageKey = "app_usage_completion_events_v1"
    private let lastIntervalStartTaskIDKey = "app_usage_last_interval_start_task_id"
    private let lastIntervalStartAtKey = "app_usage_last_interval_start_at"
    private let lastThresholdTaskIDKey = "app_usage_last_threshold_task_id"
    private let lastThresholdAtKey = "app_usage_last_threshold_at"

    init(
        defaults: KeyValueStoring? = nil,
        calendar: Calendar = .current
    ) {
        if let defaults {
            self.defaults = defaults
            self.usesAppGroupDefaults = true
        } else if let appGroupDefaults = UserDefaults(suiteName: AppGroupConfiguration.suiteName) {
            self.defaults = appGroupDefaults
            self.usesAppGroupDefaults = true
        } else {
            self.defaults = UserDefaults.standard
            self.usesAppGroupDefaults = false
            print("AppUsageCompletionEventStore: app group unavailable, using standard defaults fallback")
        }
        self.calendar = calendar
    }

    func consumeCompletedTaskIDs() -> [UUID] {
        let now = Date()
        let events = loadAll()
        saveAll([])

        var seen = Set<UUID>()
        var orderedTaskIDs: [UUID] = []

        for event in events where calendar.isDate(event.occurredAt, inSameDayAs: now) {
            if seen.insert(event.taskID).inserted {
                orderedTaskIDs.append(event.taskID)
            }
        }

        return orderedTaskIDs
    }

    func appendCompletedTaskID(_ taskID: UUID, occurredAt: Date = Date()) {
        var events = loadAll()
        events.append(AppUsageCompletionEvent(taskID: taskID, occurredAt: occurredAt))
        saveAll(events)
    }

    private func loadAll() -> [AppUsageCompletionEvent] {
        CodableStore.load(key: storageKey, defaults: defaults) ?? []
    }

    private func saveAll(_ events: [AppUsageCompletionEvent]) {
        CodableStore.save(value: events, key: storageKey, defaults: defaults)
    }
}

extension AppUsageCompletionEventStore: AppUsageCompletionEventDebugging {
    func debugSnapshot(now: Date = Date()) -> AppUsageCompletionEventDebugSnapshot {
        let events = loadAll()
        let todayCount = events.filter { calendar.isDate($0.occurredAt, inSameDayAs: now) }.count
        let lastEventAt = events.map(\.occurredAt).max()

        let defaults = self.defaults as? UserDefaults
        let intervalStartTaskID = defaults?.string(forKey: lastIntervalStartTaskIDKey)
        let intervalStartTimestamp = defaults?.double(forKey: lastIntervalStartAtKey)
        let lastIntervalStartAt: Date?
        if let intervalStartTimestamp, intervalStartTimestamp > 0 {
            lastIntervalStartAt = Date(timeIntervalSince1970: intervalStartTimestamp)
        } else {
            lastIntervalStartAt = nil
        }
        let thresholdTaskID = defaults?.string(forKey: lastThresholdTaskIDKey)
        let thresholdTimestamp = defaults?.double(forKey: lastThresholdAtKey)
        let lastThresholdAt: Date?
        if let thresholdTimestamp, thresholdTimestamp > 0 {
            lastThresholdAt = Date(timeIntervalSince1970: thresholdTimestamp)
        } else {
            lastThresholdAt = nil
        }

        return AppUsageCompletionEventDebugSnapshot(
            usesAppGroupDefaults: usesAppGroupDefaults,
            totalEventCount: events.count,
            todayEventCount: todayCount,
            lastEventAt: lastEventAt,
            lastIntervalStartTaskID: intervalStartTaskID,
            lastIntervalStartAt: lastIntervalStartAt,
            lastThresholdTaskID: thresholdTaskID,
            lastThresholdAt: lastThresholdAt
        )
    }
}
