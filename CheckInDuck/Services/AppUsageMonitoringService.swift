import Foundation
import DeviceActivity
import FamilyControls

protocol AppUsageMonitoring {
    func startMonitoring(task: HabitTask) async
    func stopMonitoring(taskID: UUID) async
}

final class AppUsageMonitoringService: AppUsageMonitoring {
    private let center = DeviceActivityCenter()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func startMonitoring(task: HabitTask) async {
        guard task.isEnabled else { return }
        guard let selection = decodeSelection(from: task.appSelectionData) else {
            print("AppUsageMonitoringService: skip monitoring, invalid app selection for task \(task.id)")
            return
        }
        let selectedTokenCount =
            selection.applicationTokens.count +
            selection.categoryTokens.count +
            selection.webDomainTokens.count
        guard selectedTokenCount > 0 else {
            print("AppUsageMonitoringService: skip monitoring, empty selection for task \(task.id)")
            return
        }

        let thresholdSeconds = max(task.usageThresholdSeconds, 1)
        let thresholdMinutes = Self.thresholdMinutes(from: thresholdSeconds)
        let event = Self.makeThresholdEvent(
            selection: selection,
            thresholdSeconds: thresholdSeconds
        )
        let recurringName = Self.activityName(for: task.id)
        let startOfTaskDay = calendar.startOfDay(for: task.effectiveRecurrenceStartDate)
        let intervalStart = task.repeatingDateComponents(
            from: startOfTaskDay,
            calendar: calendar,
            includeTime: true
        )
        let intervalEnd = task.repeatingDateComponents(
            from: startOfTaskDay.addingTimeInterval((23 * 60 * 60) + (59 * 60)),
            calendar: calendar,
            includeTime: true
        )
        let recurringSchedule = DeviceActivitySchedule(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            repeats: true
        )
        let monitoredActivityNames = Set(center.activities)

        if monitoredActivityNames.contains(recurringName) {
            center.stopMonitoring([recurringName])
            print("AppUsageMonitoringService: reconfiguring active monitor for task \(task.id)")
        }
        do {
            try center.startMonitoring(
                recurringName,
                during: recurringSchedule,
                events: [Self.thresholdEventName: event]
            )
        } catch {
            print("AppUsageMonitoringService: failed to start monitoring for task \(task.id): \(error.localizedDescription)")
        }

        if #unavailable(iOS 17.4) {
            let bootstrapName = Self.bootstrapActivityName(
                for: task.id,
                date: Date(),
                calendar: calendar
            )
            if monitoredActivityNames.contains(bootstrapName) {
                center.stopMonitoring([bootstrapName])
            }
            let startOfNow = calendar.dateComponents([.hour, .minute, .second], from: Date())
            let bootstrapSchedule = DeviceActivitySchedule(
                intervalStart: startOfNow,
                intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                repeats: false
            )
            do {
                try center.startMonitoring(
                    bootstrapName,
                    during: bootstrapSchedule,
                    events: [Self.thresholdEventName: event]
                )
            } catch {
                print("AppUsageMonitoringService: failed bootstrap monitoring for task \(task.id): \(error.localizedDescription)")
            }
        }

        let activeActivities = center.activities.map(\.rawValue).sorted()
        print(
            "AppUsageMonitoringService: started monitoring task \(task.id), selectedTokens=\(selectedTokenCount), threshold=\(thresholdSeconds)s (~\(thresholdMinutes)m), activeActivities=\(activeActivities.count)"
        )
    }

    func stopMonitoring(taskID: UUID) async {
        let namesToStop = center.activities.filter { activityName in
            Self.parseTaskID(from: activityName) == taskID
        }

        if namesToStop.isEmpty {
            center.stopMonitoring([Self.activityName(for: taskID)])
        } else {
            center.stopMonitoring(namesToStop)
        }
    }

    static let thresholdEventName = DeviceActivityEvent.Name("usage-threshold")

    static func makeThresholdEvent(
        selection: FamilyActivitySelection,
        thresholdSeconds: Int
    ) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: thresholdMinutes(from: thresholdSeconds))
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: true
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )
    }

    static func thresholdMinutes(from thresholdSeconds: Int) -> Int {
        let seconds = max(thresholdSeconds, 1)
        return max(Int(ceil(Double(seconds) / 60.0)), 1)
    }

    static func parseTaskID(from activityName: DeviceActivityName) -> UUID? {
        let raw = activityName.rawValue
        guard raw.hasPrefix(activityPrefix) else { return nil }
        let rawIdentifier = String(raw.dropFirst(activityPrefix.count))
        let uuidString: String
        if let bootstrapRange = rawIdentifier.range(of: bootstrapSuffixMarker) {
            uuidString = String(rawIdentifier[..<bootstrapRange.lowerBound])
        } else {
            uuidString = rawIdentifier
        }
        return UUID(uuidString: uuidString)
    }

    static func activityName(for taskID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(activityPrefix)\(taskID.uuidString)")
    }

    static func bootstrapActivityName(
        for taskID: UUID,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> DeviceActivityName {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        let dayStamp = String(format: "%04d%02d%02d", year, month, day)
        return DeviceActivityName("\(activityPrefix)\(taskID.uuidString)\(bootstrapSuffixMarker)\(dayStamp)")
    }

    private func decodeSelection(from data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private static let activityPrefix = "task-"
    private static let bootstrapSuffixMarker = "-bootstrap-"
}
