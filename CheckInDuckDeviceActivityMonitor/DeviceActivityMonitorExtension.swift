import DeviceActivity
import Foundation

final class DeviceActivityMonitorExtensionEntry: DeviceActivityMonitor {
    private let store = ExtensionCompletionEventStore()
    private let thresholdEventName = "usage-threshold"
    private let activityPrefix = "task-"
    private let bootstrapSuffixMarker = "-bootstrap-"

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event.rawValue == thresholdEventName else { return }
        guard let taskID = parseTaskID(from: activity.rawValue) else {
            print("DeviceActivityMonitor: threshold reached but task parse failed, activity=\(activity.rawValue)")
            return
        }
        print("DeviceActivityMonitor: threshold reached for task \(taskID.uuidString)")
        store.appendCompletedTaskID(taskID, occurredAt: Date())
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let taskID = parseTaskID(from: activity.rawValue) else {
            print("DeviceActivityMonitor: interval started but task parse failed, activity=\(activity.rawValue)")
            return
        }
        print("DeviceActivityMonitor: interval started for task \(taskID.uuidString)")
        store.recordIntervalStart(taskID, startedAt: Date())
    }

    private func parseTaskID(from activityRawValue: String) -> UUID? {
        guard activityRawValue.hasPrefix(activityPrefix) else { return nil }
        let rawIdentifier = String(activityRawValue.dropFirst(activityPrefix.count))
        let uuidString: String
        if let bootstrapRange = rawIdentifier.range(of: bootstrapSuffixMarker) {
            uuidString = String(rawIdentifier[..<bootstrapRange.lowerBound])
        } else {
            uuidString = rawIdentifier
        }
        return UUID(uuidString: uuidString)
    }
}

private struct ExtensionCompletionEvent: Codable {
    let taskID: UUID
    let occurredAt: Date
}

private final class ExtensionCompletionEventStore {
    private let defaults = UserDefaults(suiteName: "group.com.wang.CheckInDuck")
    private let storageKey = "app_usage_completion_events_v1"
    private let lastThresholdTaskIDKey = "app_usage_last_threshold_task_id"
    private let lastThresholdAtKey = "app_usage_last_threshold_at"
    private let lastIntervalStartTaskIDKey = "app_usage_last_interval_start_task_id"
    private let lastIntervalStartAtKey = "app_usage_last_interval_start_at"

    func appendCompletedTaskID(_ taskID: UUID, occurredAt: Date) {
        guard let defaults else {
            print("DeviceActivityMonitor: app group defaults unavailable, threshold event dropped")
            return
        }
        var events = loadAll()
        events.append(ExtensionCompletionEvent(taskID: taskID, occurredAt: occurredAt))
        saveAll(events)
        defaults.set(taskID.uuidString, forKey: lastThresholdTaskIDKey)
        defaults.set(occurredAt.timeIntervalSince1970, forKey: lastThresholdAtKey)
    }

    func recordIntervalStart(_ taskID: UUID, startedAt: Date) {
        guard let defaults else { return }
        defaults.set(taskID.uuidString, forKey: lastIntervalStartTaskIDKey)
        defaults.set(startedAt.timeIntervalSince1970, forKey: lastIntervalStartAtKey)
    }

    private func loadAll() -> [ExtensionCompletionEvent] {
        guard let defaults else { return [] }
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ExtensionCompletionEvent].self, from: data)) ?? []
    }

    private func saveAll(_ events: [ExtensionCompletionEvent]) {
        guard let defaults else { return }
        let data = try? JSONEncoder().encode(events)
        defaults.set(data, forKey: storageKey)
    }
}
