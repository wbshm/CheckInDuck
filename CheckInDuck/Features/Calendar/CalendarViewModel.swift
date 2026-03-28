import Foundation
import Combine

struct CalendarDaySummary: Equatable {
    let date: Date
    let completedCount: Int
    let pendingCount: Int
    let missedCount: Int
    let isRestricted: Bool
    let hasNote: Bool

    var totalCount: Int {
        completedCount + pendingCount + missedCount
    }

    var hasData: Bool {
        !isRestricted && totalCount > 0
    }

    var hasContent: Bool {
        !isRestricted && (totalCount > 0 || hasNote)
    }

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

struct CalendarDayTaskDetail: Identifiable, Equatable {
    let id: String
    let taskID: UUID?
    let taskName: String
    let status: DailyTaskStatus
    let completionSource: CompletionSource?
}

struct CalendarDayDetail: Equatable {
    let date: Date
    let summary: CalendarDaySummary
    let taskDetails: [CalendarDayTaskDetail]
    let noteText: String?
}

struct CalendarDailyActivity: Identifiable, Equatable {
    let date: Date
    let day: Int
    let totalCount: Int
    let completedCount: Int

    var id: Date { date }
}

struct CalendarMonthInsights: Equatable {
    let monthStart: Date
    let dayCount: Int
    let activeDays: Int
    let completedCount: Int
    let pendingCount: Int
    let missedCount: Int
    let completionRate: Double?
    let dailyActivities: [CalendarDailyActivity]
    let peakActivity: CalendarDailyActivity?
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
    @Published private(set) var notes: [CalendarDayNote] = []
    @Published private(set) var monthAnchor: Date
    @Published var selectedDate: Date?

    private let taskStore: TaskStore
    private let dailyRecordStore: DailyRecordStore
    private let dayNoteStore: CalendarDayNoteStore
    private let calendar: Calendar
    private let statusCalculator: DailyStatusCalculator
    private let subscriptionAccess: SubscriptionAccessProviding
    private let nowProvider: () -> Date

    convenience init(subscriptionAccess: SubscriptionAccessProviding) {
        self.init(
            taskStore: TaskStore(),
            dailyRecordStore: DailyRecordStore(),
            dayNoteStore: CalendarDayNoteStore(),
            calendar: .current,
            subscriptionAccess: subscriptionAccess
        )
    }

    init(
        taskStore: TaskStore,
        dailyRecordStore: DailyRecordStore,
        dayNoteStore: CalendarDayNoteStore? = nil,
        calendar: Calendar,
        subscriptionAccess: SubscriptionAccessProviding,
        monthAnchor: Date = Date(),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.taskStore = taskStore
        self.dailyRecordStore = dailyRecordStore
        self.dayNoteStore = dayNoteStore ?? CalendarDayNoteStore()
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
        notes = dayNoteStore.loadAll()
        monthAnchor = clampedMonthAnchor(monthAnchor)
        normalizeSelectionIfNeeded()
    }

    func moveMonth(by offset: Int) {
        guard offset != 0 else { return }
        if offset < 0 && !canMoveToPreviousMonth {
            return
        }
        if offset > 0 && !canMoveToNextMonth {
            return
        }
        guard let moved = calendar.date(byAdding: .month, value: offset, to: monthAnchor) else {
            return
        }
        monthAnchor = clampedMonthAnchor(Self.startOfMonth(for: moved, calendar: calendar))
        selectedDate = nil
    }

    var monthTitle: String {
        monthAnchor.formatted(.dateTime.year().month(.wide))
    }

    var canMoveToPreviousMonth: Bool {
        monthAnchor > minimumMonthWithData
    }

    var canMoveToNextMonth: Bool {
        monthAnchor < maximumMonthWithData
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

        let summaryByDate = Dictionary(
            uniqueKeysWithValues: summariesForMonth(monthAnchor).map { summary in
                (summary.date, summary)
            }
        )

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingPadding = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [CalendarGridCell] = (0..<leadingPadding).map {
            .placeholder(id: "leading-\($0)")
        }

        for day in dayRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: date)
            let summary = summaryByDate[dayStart] ?? summary(for: dayStart)
            cells.append(.day(date: dayStart, summary: summary))
        }

        let trailingPadding = (7 - (cells.count % 7)) % 7
        cells.append(contentsOf: (0..<trailingPadding).map { .placeholder(id: "trailing-\($0)") })
        return cells
    }

    func summary(for date: Date) -> CalendarDaySummary {
        let dayStart = calendar.startOfDay(for: date)
        return dayComputation(for: dayStart).summary
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: nowProvider())
    }

    func isSelected(_ date: Date) -> Bool {
        guard let selectedDate else {
            return false
        }
        return calendar.isDate(selectedDate, inSameDayAs: date)
    }

    func selectDate(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        let summary = summary(for: dayStart)
        guard summary.hasContent else {
            return
        }
        selectedDate = dayStart
    }

    var selectedDayDetail: CalendarDayDetail? {
        guard let selectedDate else {
            return nil
        }
        return dayDetail(for: selectedDate)
    }

    func dayDetail(for date: Date) -> CalendarDayDetail? {
        let dayStart = calendar.startOfDay(for: date)
        let computation = dayComputation(for: dayStart)
        guard computation.summary.hasContent else {
            return nil
        }
        return CalendarDayDetail(
            date: dayStart,
            summary: computation.summary,
            taskDetails: computation.taskDetails,
            noteText: noteText(for: dayStart)
        )
    }

    func noteText(for date: Date) -> String? {
        let dayStart = calendar.startOfDay(for: date)
        return notes.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) })?.text
    }

    func updateNote(_ text: String, for date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        dayNoteStore.upsert(text: text, for: dayStart, calendar: calendar)
        notes = dayNoteStore.loadAll()
    }

    func completionSourceText(for source: CompletionSource?) -> String? {
        switch source {
        case .manual:
            return L10n.tr("history.source.manual")
        case .appUsageThreshold:
            return L10n.tr("history.source.app_usage")
        case nil:
            return nil
        }
    }

    var monthInsights: CalendarMonthInsights {
        let summaries = summariesForMonth(monthAnchor).filter { !$0.isRestricted }
        let dayCount = summaries.count
        let activeDays = summaries.filter(\.hasData).count
        let completedCount = summaries.reduce(0) { $0 + $1.completedCount }
        let pendingCount = summaries.reduce(0) { $0 + $1.pendingCount }
        let missedCount = summaries.reduce(0) { $0 + $1.missedCount }
        let totalCount = completedCount + pendingCount + missedCount
        let completionRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : nil
        let activities = summaries.map { summary in
            CalendarDailyActivity(
                date: summary.date,
                day: calendar.component(.day, from: summary.date),
                totalCount: summary.totalCount,
                completedCount: summary.completedCount
            )
        }
        let peakActivity = activities
            .filter { $0.totalCount > 0 }
            .max { lhs, rhs in
                if lhs.totalCount == rhs.totalCount {
                    return lhs.day > rhs.day
                }
                return lhs.totalCount < rhs.totalCount
            }

        return CalendarMonthInsights(
            monthStart: monthAnchor,
            dayCount: dayCount,
            activeDays: activeDays,
            completedCount: completedCount,
            pendingCount: pendingCount,
            missedCount: missedCount,
            completionRate: completionRate,
            dailyActivities: activities,
            peakActivity: peakActivity
        )
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

    private func dayComputation(for date: Date) -> (summary: CalendarDaySummary, taskDetails: [CalendarDayTaskDetail]) {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: nowProvider())
        let noteText = noteText(for: dayStart)
        let hasNote = !(noteText?.isEmpty ?? true)

        if isRestricted(date: dayStart, todayStart: todayStart) {
            return (
                CalendarDaySummary(
                    date: dayStart,
                    completedCount: 0,
                    pendingCount: 0,
                    missedCount: 0,
                    isRestricted: true,
                    hasNote: false
                ),
                []
            )
        }

        let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
        let dayRecordByTaskID = latestRecordByTaskID(records: dayRecords)

        if dayStart > todayStart && dayRecordByTaskID.isEmpty {
            return (
                CalendarDaySummary(
                    date: dayStart,
                    completedCount: 0,
                    pendingCount: 0,
                    missedCount: 0,
                    isRestricted: false,
                    hasNote: hasNote
                ),
                []
            )
        }

        let candidateTasks = tasks.filter { task in
            let createdDay = calendar.startOfDay(for: task.createdAt)
            let hasRecordForDay = dayRecordByTaskID[task.id] != nil
            guard createdDay <= dayStart else { return false }
            guard task.occurs(on: dayStart, calendar: calendar) || hasRecordForDay else { return false }

            if dayStart > todayStart {
                return hasRecordForDay
            }
            return task.isEnabled || hasRecordForDay
        }

        if candidateTasks.isEmpty && dayRecordByTaskID.isEmpty {
            return (
                CalendarDaySummary(
                    date: dayStart,
                    completedCount: 0,
                    pendingCount: 0,
                    missedCount: 0,
                    isRestricted: false,
                    hasNote: hasNote
                ),
                []
            )
        }

        var completedCount = 0
        var pendingCount = 0
        var missedCount = 0
        var taskDetails: [CalendarDayTaskDetail] = []
        let evaluationNow = evaluationMoment(for: dayStart, todayStart: todayStart)
        let candidateTaskIDs = Set(candidateTasks.map(\.id))

        for task in candidateTasks {
            let record = dayRecordByTaskID[task.id]
            let status = record?.status ?? statusCalculator.status(
                for: task,
                records: records,
                now: evaluationNow
            )
            increment(status, completedCount: &completedCount, pendingCount: &pendingCount, missedCount: &missedCount)

            taskDetails.append(
                CalendarDayTaskDetail(
                    id: "task-\(task.id.uuidString)",
                    taskID: task.id,
                    taskName: task.name,
                    status: status,
                    completionSource: record?.completionSource
                )
            )
        }

        let outOfTaskRecords = dayRecordByTaskID.values.filter { !candidateTaskIDs.contains($0.taskId) }
        for record in outOfTaskRecords {
            increment(record.status, completedCount: &completedCount, pendingCount: &pendingCount, missedCount: &missedCount)
            taskDetails.append(
                CalendarDayTaskDetail(
                    id: "orphan-\(record.id.uuidString)",
                    taskID: record.taskId,
                    taskName: L10n.tr("history.unknown_task"),
                    status: record.status,
                    completionSource: record.completionSource
                )
            )
        }

        let sortedTaskDetails = taskDetails.sorted { lhs, rhs in
            let lhsPriority = statusPriority(lhs.status)
            let rhsPriority = statusPriority(rhs.status)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.taskName.localizedCaseInsensitiveCompare(rhs.taskName) == .orderedAscending
        }

        return (
            CalendarDaySummary(
                date: dayStart,
                completedCount: completedCount,
                pendingCount: pendingCount,
                missedCount: missedCount,
                isRestricted: false,
                hasNote: hasNote
            ),
            sortedTaskDetails
        )
    }

    private func summariesForMonth(_ month: Date) -> [CalendarDaySummary] {
        guard
            let dayRange = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }

        return dayRange.compactMap { day -> CalendarDaySummary? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) else {
                return nil
            }
            return dayComputation(for: date).summary
        }
    }

    private func increment(
        _ status: DailyTaskStatus,
        completedCount: inout Int,
        pendingCount: inout Int,
        missedCount: inout Int
    ) {
        switch status {
        case .completed:
            completedCount += 1
        case .pending:
            pendingCount += 1
        case .missed:
            missedCount += 1
        }
    }

    private func statusPriority(_ status: DailyTaskStatus) -> Int {
        switch status {
        case .missed:
            return 0
        case .pending:
            return 1
        case .completed:
            return 2
        }
    }

    private var minimumMonthWithData: Date {
        Self.startOfMonth(for: minimumVisibleDate, calendar: calendar)
    }

    private var maximumMonthWithData: Date {
        Self.startOfMonth(for: maximumVisibleDate, calendar: calendar)
    }

    private var minimumVisibleDate: Date {
        let todayStart = calendar.startOfDay(for: nowProvider())
        var candidates: [Date] = [todayStart]
        candidates.append(contentsOf: tasks.map { calendar.startOfDay(for: $0.createdAt) })
        candidates.append(contentsOf: records.map { calendar.startOfDay(for: $0.date) })
        candidates.append(contentsOf: notes.map { calendar.startOfDay(for: $0.date) })

        let rawMinimum = candidates.min() ?? todayStart
        guard
            let lookbackDays = subscriptionAccess.historyLookbackDays(),
            let cutoff = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: todayStart)
        else {
            return rawMinimum
        }
        return maxDate(rawMinimum, cutoff)
    }

    private var maximumVisibleDate: Date {
        let todayStart = calendar.startOfDay(for: nowProvider())
        let latestRecordDate = records
            .map { calendar.startOfDay(for: $0.date) }
            .max() ?? todayStart
        let latestNoteDate = notes
            .map { calendar.startOfDay(for: $0.date) }
            .max() ?? todayStart
        return maxDate(maxDate(todayStart, latestRecordDate), latestNoteDate)
    }

    private func clampedMonthAnchor(_ month: Date) -> Date {
        let normalizedMonth = Self.startOfMonth(for: month, calendar: calendar)
        if normalizedMonth < minimumMonthWithData {
            return minimumMonthWithData
        }
        if normalizedMonth > maximumMonthWithData {
            return maximumMonthWithData
        }
        return normalizedMonth
    }

    private func normalizeSelectionIfNeeded() {
        guard let selectedDate else {
            selectDefaultDateIfNeeded()
            return
        }
        let dayStart = calendar.startOfDay(for: selectedDate)
        if !calendar.isDate(dayStart, equalTo: monthAnchor, toGranularity: .month) {
            self.selectedDate = nil
            selectDefaultDateIfNeeded()
            return
        }
        self.selectedDate = dayStart
    }

    private func selectDefaultDateIfNeeded() {
        let todayStart = calendar.startOfDay(for: nowProvider())
        guard calendar.isDate(todayStart, equalTo: monthAnchor, toGranularity: .month) else {
            return
        }
        selectedDate = todayStart
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
