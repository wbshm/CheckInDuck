import Foundation
import Combine

enum HistoryDisplayMode: String, CaseIterable, Identifiable {
    case byDay
    case byTask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byDay:
            return L10n.tr("history.display.by_day")
        case .byTask:
            return L10n.tr("history.display.by_task")
        }
    }
}

struct HistoryDaySection: Identifiable {
    let date: Date
    let records: [DailyRecord]

    var id: Date { date }
}

struct HistoryTaskSection: Identifiable {
    let taskID: UUID
    let taskName: String
    let records: [DailyRecord]

    var id: UUID { taskID }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var tasks: [HabitTask] = []
    @Published private(set) var records: [DailyRecord] = []
    @Published var displayMode: HistoryDisplayMode = .byDay
    @Published var selectedTaskID: UUID?

    private let taskStore: TaskStore
    private let dailyRecordStore: DailyRecordStore
    private let calendar: Calendar
    private let subscriptionAccess: SubscriptionAccessProviding
    private let nowProvider: () -> Date

    convenience init() {
        self.init(
            taskStore: TaskStore(),
            dailyRecordStore: DailyRecordStore(),
            calendar: .current,
            subscriptionAccess: SubscriptionAccessService()
        )
    }

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
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.taskStore = taskStore
        self.dailyRecordStore = dailyRecordStore
        self.calendar = calendar
        self.subscriptionAccess = subscriptionAccess
        self.nowProvider = nowProvider
        reload()
    }

    func reload() {
        tasks = taskStore.loadAll().sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        records = dailyRecordStore
            .loadAll()
            .filter { $0.status == .completed || $0.status == .missed }
            .sorted(by: recordSort)

        if !isTaskFilterEnabled {
            selectedTaskID = nil
        }
    }

    var availableTasks: [HabitTask] {
        tasks
    }

    var isTaskFilterEnabled: Bool {
        subscriptionAccess.isFeatureEnabled(.advancedHistoryFilters)
    }

    var filteredRecords: [DailyRecord] {
        let recordsToDisplay = recordsByTaskFilter

        guard let lookbackDays = subscriptionAccess.historyLookbackDays() else {
            return recordsToDisplay
        }

        let startOfToday = calendar.startOfDay(for: nowProvider())
        guard let cutoffDate = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: startOfToday) else {
            return recordsToDisplay
        }

        return recordsToDisplay.filter { record in
            calendar.startOfDay(for: record.date) >= cutoffDate
        }
    }

    var daySections: [HistoryDaySection] {
        let grouped = Dictionary(grouping: filteredRecords) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped.keys.sorted(by: >).map { date in
            let dayRecords = (grouped[date] ?? []).sorted(by: recordSort)
            return HistoryDaySection(date: date, records: dayRecords)
        }
    }

    var taskSections: [HistoryTaskSection] {
        let grouped = Dictionary(grouping: filteredRecords, by: \.taskId)

        return grouped.keys
            .sorted { taskName(for: $0) < taskName(for: $1) }
            .map { taskID in
                let taskRecords = (grouped[taskID] ?? []).sorted(by: recordSort)
                return HistoryTaskSection(
                    taskID: taskID,
                    taskName: taskName(for: taskID),
                    records: taskRecords
                )
            }
    }

    func taskName(for taskID: UUID) -> String {
        tasks.first(where: { $0.id == taskID })?.name ?? L10n.tr("history.unknown_task")
    }

    func completionSourceText(for record: DailyRecord) -> String {
        switch record.completionSource {
        case .manual:
            return L10n.tr("history.source.manual")
        case .appUsageThreshold:
            return L10n.tr("history.source.app_usage")
        case nil:
            return L10n.tr("history.source.not_completed")
        }
    }

    private func recordSort(_ lhs: DailyRecord, _ rhs: DailyRecord) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }

        let lhsCompletionDate = lhs.completedAt ?? lhs.date
        let rhsCompletionDate = rhs.completedAt ?? rhs.date
        return lhsCompletionDate > rhsCompletionDate
    }

    private var recordsByTaskFilter: [DailyRecord] {
        guard isTaskFilterEnabled, let selectedTaskID else {
            return records
        }
        return records.filter { $0.taskId == selectedTaskID }
    }
}
