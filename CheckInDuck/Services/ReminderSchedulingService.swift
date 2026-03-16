import Foundation
import UserNotifications

protocol ReminderScheduling {
    func scheduleReminders(for task: HabitTask) async
    func cancelReminders(for taskID: UUID) async
}

final class ReminderSchedulingService: ReminderScheduling {
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
            let content = UNMutableNotificationContent()
            content.title = "Task Reminder"
            content.body = "\(task.name) is due at \(task.deadline.displayText)."
            content.sound = .default

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

        let validOffsets = task.reminderConfig.offsetsInMinutes.filter { offset in
            offset > 0 && offset < 24 * 60
        }

        return validOffsets.compactMap { offset in
            guard let reminderDate = calendar.date(byAdding: .minute, value: -offset, to: deadlineToday) else {
                return nil
            }
            let triggerDate = calendar.dateComponents([.hour, .minute], from: reminderDate)
            return (offsetMinutes: offset, triggerDate: triggerDate)
        }
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

    private func pendingRequests(from center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
