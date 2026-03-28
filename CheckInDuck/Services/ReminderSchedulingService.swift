import Foundation
import UserNotifications

protocol ReminderScheduling {
    func scheduleReminders(for task: HabitTask) async
    func cancelReminders(for taskID: UUID) async
}

final class ReminderSchedulingService: ReminderScheduling {
    private enum NotificationStagger {
        static let reminderSecondRange = 50
    }

    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func scheduleReminders(for task: HabitTask) async {
        let center = UNUserNotificationCenter.current()
        await cancelReminders(for: task.id)

        guard AppPreferences.remindersEnabled() else { return }
        guard task.reminderConfig.isEnabled else { return }
        let triggerComponents = reminderScheduleComponents(for: task)

        for (offset, triggerDate) in triggerComponents {
            let content = makeReminderContent(for: task, offsetMinutes: offset)

            let request = UNNotificationRequest(
                identifier: reminderIdentifier(taskID: task.id, offsetMinutes: offset),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
            )
            try? await center.add(request)
        }
    }

    func cancelReminders(for taskID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let prefix = "task-reminder-\(taskID.uuidString)-"
        let pendingRequests = await pendingRequests(from: center)
        let identifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func reminderScheduleComponents(
        for task: HabitTask,
        referenceDate: Date? = nil
    ) -> [(offsetMinutes: Int, triggerDate: DateComponents)] {
        let now = referenceDate ?? nowProvider()
        guard let deadlineToday = dateFromDeadline(task.deadline, referenceDate: now) else {
            return []
        }

        let positiveOffsets = task.reminderConfig.offsetsInMinutes.filter { offset in
            offset > 0 && offset < 24 * 60
        }
        let validOffsets = Array(Set(positiveOffsets + [0])).sorted(by: >)

        return validOffsets.compactMap { offset in
            guard let reminderDate = calendar.date(byAdding: .minute, value: -offset, to: deadlineToday) else {
                return nil
            }
            let triggerDate = task.recurrence.repeatingDateComponents(
                from: reminderDate,
                calendar: calendar,
                includeTime: true,
                second: staggerSecond(for: task.id, offsetMinutes: offset)
            )
            return (offsetMinutes: offset, triggerDate: triggerDate)
        }
    }

    func makeReminderContent(for task: HabitTask, offsetMinutes: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let isDeadlineReminder = offsetMinutes == 0

        if isDeadlineReminder {
            content.title = "Check-in Due Now"
            content.body = "\(task.name) deadline reached. Open CheckInDuck now to avoid missing today."
        } else {
            content.title = "Task Reminder"
            content.body = "\(task.name) is due at \(task.deadline.displayText)."
        }

        content.sound = .default
        content.threadIdentifier = "task-reminders"

        if #available(iOS 15.0, *) {
            content.interruptionLevel = isDeadlineReminder ? .timeSensitive : .active
            content.relevanceScore = isDeadlineReminder ? 1.0 : 0.5
        }

        return content
    }

    private func reminderIdentifier(taskID: UUID, offsetMinutes: Int) -> String {
        "task-reminder-\(taskID.uuidString)-\(offsetMinutes)"
    }

    private func dateFromDeadline(_ deadline: DailyDeadline, referenceDate: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = deadline.hour
        components.minute = deadline.minute
        return calendar.date(from: components)
    }

    private func staggerSecond(for taskID: UUID, offsetMinutes: Int) -> Int {
        guard offsetMinutes > 0 else { return 0 }

        let range = NotificationStagger.reminderSecondRange

        let seed = taskID.uuidString.unicodeScalars.reduce(offsetMinutes * 37) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
        return abs(seed) % max(range, 1)
    }

    private func pendingRequests(from center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
