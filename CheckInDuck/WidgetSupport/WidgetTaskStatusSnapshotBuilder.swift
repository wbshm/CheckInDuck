import Foundation

struct WidgetTaskStatusSnapshot: Equatable {
    let title: String
    let status: DailyTaskStatus
    let deadlineText: String
}

struct WidgetTodaySnapshot: Equatable {
    let pendingCount: Int
    let completedCount: Int
    let missedCount: Int
    let tasks: [WidgetTaskStatusSnapshot]
}

struct WidgetTaskStatusSnapshotBuilder {
    private let calendar: Calendar
    private let calculator: DailyStatusCalculator

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.calculator = DailyStatusCalculator(calendar: calendar)
    }

    func build(
        tasks: [HabitTask],
        records: [DailyRecord],
        now: Date = Date()
    ) -> WidgetTodaySnapshot {
        let visibleTasks = tasks
            .filter(\.isEnabled)
            .map { task in
                WidgetTaskStatusSnapshot(
                    title: task.name,
                    status: calculator.status(for: task, records: records, now: now),
                    deadlineText: task.deadline.displayText
                )
            }
            .sorted(by: compareTasks)

        let pendingCount = visibleTasks.filter { $0.status == .pending }.count
        let completedCount = visibleTasks.filter { $0.status == .completed }.count
        let missedCount = visibleTasks.filter { $0.status == .missed }.count

        return WidgetTodaySnapshot(
            pendingCount: pendingCount,
            completedCount: completedCount,
            missedCount: missedCount,
            tasks: visibleTasks
        )
    }

    private func compareTasks(
        _ lhs: WidgetTaskStatusSnapshot,
        _ rhs: WidgetTaskStatusSnapshot
    ) -> Bool {
        let lhsPriority = statusPriority(lhs.status)
        let rhsPriority = statusPriority(rhs.status)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        if lhs.deadlineText != rhs.deadlineText {
            return lhs.deadlineText < rhs.deadlineText
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func statusPriority(_ status: DailyTaskStatus) -> Int {
        switch status {
        case .pending:
            return 0
        case .missed:
            return 1
        case .completed:
            return 2
        }
    }
}
