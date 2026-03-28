import Foundation

struct DailyStatusCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func status(
        for task: HabitTask,
        records: [DailyRecord],
        now: Date = Date()
    ) -> DailyTaskStatus {
        if let todayRecord = todayRecord(for: task.id, records: records, now: now) {
            return todayRecord.status
        }
        guard task.isEnabled else {
            return .pending
        }
        guard task.occurs(on: now, calendar: calendar) else {
            return .pending
        }
        return isPastDeadline(task: task, now: now) ? .missed : .pending
    }

    func missingRecordsToInsert(
        for tasks: [HabitTask],
        existingRecords: [DailyRecord],
        now: Date = Date()
    ) -> [DailyRecord] {
        let today = calendar.startOfDay(for: now)

        return tasks.compactMap { task in
            guard task.isEnabled else { return nil }
            guard task.occurs(on: today, calendar: calendar) else { return nil }
            guard todayRecord(for: task.id, records: existingRecords, now: now) == nil else { return nil }
            guard isPastDeadline(task: task, now: now) else { return nil }

            return DailyRecord(
                taskId: task.id,
                date: today,
                status: .missed
            )
        }
    }

    private func todayRecord(
        for taskID: UUID,
        records: [DailyRecord],
        now: Date
    ) -> DailyRecord? {
        records.first {
            $0.taskId == taskID && calendar.isDate($0.date, inSameDayAs: now)
        }
    }

    private func isPastDeadline(task: HabitTask, now: Date) -> Bool {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = task.deadline.hour
        components.minute = task.deadline.minute
        guard let deadlineDate = calendar.date(from: components) else {
            return false
        }
        return now >= deadlineDate
    }
}
