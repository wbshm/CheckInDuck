import Foundation
import Combine

struct CalendarDaySummary: Equatable {
    let date: Date
    let completedCount: Int
    let pendingCount: Int
    let missedCount: Int
    let isRestricted: Bool

    var primaryStatus: DailyTaskStatus? {
        guard !isRestricted else { return nil }
        if missedCount > 0 { return .missed }
        if pendingCount > 0 { return .pending }
        if completedCount > 0 { return .completed }
        return nil
    }

    var statusIndicators: [DailyTaskStatus] {
        guard !isRestricted else { return [] }

        var result: [DailyTaskStatus] = []
        if completedCount > 0 {
            result.append(.completed)
        }
        if pendingCount > 0 {
            result.append(.pending)
        }
        if missedCount > 0 {
            result.append(.missed)
        }
        return result
    }
}

struct CalendarGridCell: Identifiable, Equatable {
    let id: String
    let date: Date?
    let summary: CalendarDaySummary?

    static func placeholder(id: String) -> CalendarGridCell {
        CalendarGridCell(id: id, date: nil, summary: nil)
    }

    static func day(date: Date, summary: CalendarDaySummary) -> CalendarGridCell {
        CalendarGridCell(
            id: "day-\(Int(date.timeIntervalSince1970))",
            date: date,
            summary: summary
        )
    }
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var tasks: [HabitTask] = []
    @Published private(set) var records: [DailyRecord] = []
    @Published private(set) var monthAnchor: Date

    private let taskStore: TaskStore
    private let dailyRecordStore: DailyRecordStore
    private let calendar: Calendar
    private let statusCalculator: DailyStatusCalculator
    private let subscriptionAccess: SubscriptionAccessProviding
    private let nowProvider: () -> Date

    convenience init(subscriptionAccess: SubscriptionAccessProviding) {
        self.init(
            taskStore: TaskStore(),
            dailyRecordStore: DailyRecordStore(),
            calendar: .current,
            subscriptionAccess: subscriptionAccess
        )
    }

    init(
        taskStore: TaskStore,
        dailyRecordStore: DailyRecordStore,
        calendar: Calendar,
        subscriptionAccess: SubscriptionAccessProviding,
        monthAnchor: Date = Date(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.taskStore = taskStore
        self.dailyRecordStore = dailyRecordStore
        self.calendar = calendar
        self.statusCalculator = DailyStatusCalculator(calendar: calendar)
        self.subscriptionAccess = subscriptionAccess
        self.nowProvider = nowProvider
        self.monthAnchor = Self.startOfMonth(for: monthAnchor, calendar: calendar)
        reload()
    }

    func reload() {
        tasks = taskStore.loadAll()
        records = dailyRecordStore.loadAll()
    }

    func moveMonth(by offset: Int) {
        guard let moved = calendar.date(byAdding: .month, value: offset, to: monthAnchor) else {
            return
        }
        monthAnchor = Self.startOfMonth(for: moved, calendar: calendar)
    }

    var monthTitle: String {
        monthAnchor.formatted(.dateTime.year().month(.wide))
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let firstIndex = max(0, min(calendar.firstWeekday - 1, symbols.count - 1))
        let leading = Array(symbols[firstIndex...])
        let trailing = Array(symbols[..<firstIndex])
        return leading + trailing
    }

    var dayCells: [CalendarGridCell] {
        guard
            let dayRange = calendar.range(of: .day, in: .month, for: monthAnchor),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor))
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingPadding = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [CalendarGridCell] = (0..<leadingPadding).map {
            .placeholder(id: "leading-\($0)")
        }

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) else {
                continue
            }
            cells.append(.day(date: date, summary: summary(for: date)))
        }

        let trailingPadding = (7 - (cells.count % 7)) % 7
        cells.append(contentsOf: (0..<trailingPadding).map { .placeholder(id: "trailing-\($0)") })
        return cells
    }

    func summary(for date: Date) -> CalendarDaySummary {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: nowProvider())

        if isRestricted(date: dayStart, todayStart: todayStart) {
            return CalendarDaySummary(
                date: dayStart,
                completedCount: 0,
                pendingCount: 0,
                missedCount: 0,
                isRestricted: true
            )
        }

        if dayStart > todayStart {
            return CalendarDaySummary(
                date: dayStart,
                completedCount: 0,
                pendingCount: 0,
                missedCount: 0,
                isRestricted: false
            )
        }

        let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
        let dayRecordByTaskID = latestRecordByTaskID(records: dayRecords)

        let candidateTasks = tasks.filter { task in
            let createdDay = calendar.startOfDay(for: task.createdAt)
            let hasRecordForDay = dayRecordByTaskID[task.id] != nil
            return createdDay <= dayStart && (task.isEnabled || hasRecordForDay)
        }

        if candidateTasks.isEmpty && dayRecordByTaskID.isEmpty {
            return CalendarDaySummary(
                date: dayStart,
                completedCount: 0,
                pendingCount: 0,
                missedCount: 0,
                isRestricted: false
            )
        }

        var completedCount = 0
        var pendingCount = 0
        var missedCount = 0
        let evaluationNow = evaluationMoment(for: dayStart, todayStart: todayStart)
        let candidateTaskIDs = Set(candidateTasks.map(\.id))

        for task in candidateTasks {
            let status = dayRecordByTaskID[task.id]?.status ?? statusCalculator.status(
                for: task,
                records: records,
                now: evaluationNow
            )
            switch status {
            case .completed:
                completedCount += 1
            case .pending:
                pendingCount += 1
            case .missed:
                missedCount += 1
            }
        }

        let outOfTaskRecords = dayRecordByTaskID.values.filter { !candidateTaskIDs.contains($0.taskId) }
        for record in outOfTaskRecords {
            switch record.status {
            case .completed:
                completedCount += 1
            case .pending:
                pendingCount += 1
            case .missed:
                missedCount += 1
            }
        }

        return CalendarDaySummary(
            date: dayStart,
            completedCount: completedCount,
            pendingCount: pendingCount,
            missedCount: missedCount,
            isRestricted: false
        )
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: nowProvider())
    }

    private func isRestricted(date: Date, todayStart: Date) -> Bool {
        guard let lookbackDays = subscriptionAccess.historyLookbackDays() else {
            return false
        }
        guard let cutoff = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: todayStart) else {
            return false
        }
        return date < cutoff
    }

    private func evaluationMoment(for dayStart: Date, todayStart: Date) -> Date {
        if dayStart == todayStart {
            return nowProvider()
        }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nowProvider()
        }
        return nextDay.addingTimeInterval(-1)
    }

    private func latestRecordByTaskID(records: [DailyRecord]) -> [UUID: DailyRecord] {
        let grouped = Dictionary(grouping: records, by: \.taskId)
        return grouped.mapValues { records in
            records.max(by: { lhs, rhs in
                recordDate(for: lhs) < recordDate(for: rhs)
            }) ?? records[0]
        }
    }

    private func recordDate(for record: DailyRecord) -> Date {
        record.completedAt ?? record.date
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
